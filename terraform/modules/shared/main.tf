##### PHI Storage Account #####

resource "azurerm_storage_account" "phi" {
  name                     = "phdi${terraform.workspace}phi${substr(var.client_id, 0, 8)}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "GRS"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.pipeline_runner.id]
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "azurerm_storage_container" "source_data" {
  name                 = "source-data"
  storage_account_name = azurerm_storage_account.phi.name
}

resource "azurerm_storage_blob" "vxu" {
  name                   = "vxu/.keep"
  storage_account_name   = azurerm_storage_account.phi.name
  storage_container_name = azurerm_storage_container.source_data.name
  type                   = "Block"
  source_content         = ""
}

resource "azurerm_storage_blob" "ecr" {
  name                   = "ecr/.keep"
  storage_account_name   = azurerm_storage_account.phi.name
  storage_container_name = azurerm_storage_container.source_data.name
  type                   = "Block"
  source_content         = ""
}

resource "azurerm_storage_blob" "elr" {
  name                   = "elr/.keep"
  storage_account_name   = azurerm_storage_account.phi.name
  storage_container_name = azurerm_storage_container.source_data.name
  type                   = "Block"
  source_content         = ""
}

resource "azurerm_storage_container" "fhir_conversion_failures_container_name" {
  name                 = "fhir-conversion-failures"
  storage_account_name = azurerm_storage_account.phi.name
}

resource "azurerm_storage_container" "fhir_upload_failures_container_name" {
  name                 = "fhir-upload-failures"
  storage_account_name = azurerm_storage_account.phi.name
}

resource "azurerm_role_assignment" "phi_storage_contributor" {
  scope                = azurerm_storage_account.phi.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.pipeline_runner.principal_id
}

resource "azurerm_storage_share" "tables" {
  name                 = "phdi${terraform.workspace}tables"
  storage_account_name = azurerm_storage_account.phi.name
  quota                = 50
  enabled_protocol     = "SMB"
}

##### Key Vault #####

resource "azurerm_key_vault" "phdi_key_vault" {
  name                       = "${terraform.workspace}vault${substr(var.client_id, 0, 8)}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7


  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.pipeline_runner.principal_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]
  }
}

resource "random_uuid" "salt" {}

resource "azurerm_key_vault_secret" "salt" {
  name         = "patient-hash-salt"
  value        = random_uuid.salt.result
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

resource "azurerm_key_vault_secret" "smarty_auth_id" {
  name         = "smarty-auth-id"
  value        = var.smarty_auth_id
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

resource "azurerm_key_vault_secret" "smarty_auth_token" {
  name         = "smarty-auth-token"
  value        = var.smarty_auth_token
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

##### Container registry #####

resource "azurerm_container_registry" "phdi_registry" {
  name                = "phdi${terraform.workspace}registry${substr(var.client_id, 0, 8)}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = true
}

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.1"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
  registry_auth {
    address  = "ghcr.io"
    username = var.ghcr_username
    password = var.ghcr_token
  }
  registry_auth {
    address  = azurerm_container_registry.phdi_registry.login_server
    username = azurerm_container_registry.phdi_registry.admin_username
    password = azurerm_container_registry.phdi_registry.admin_password
  }
}

# Pull images from GitHub Container Registry and push to Azure Container Registry
locals {
  images = toset([
    "fhir-converter",
    "ingestion",
    "tabulation",
    "alerts",
    "message-parser",
    "validation",
  ])
}

data "docker_registry_image" "ghcr_data" {
  for_each = local.images
  name     = "ghcr.io/cdcgov/phdi/${each.key}:main"
}

resource "docker_image" "ghcr_image" {
  for_each      = local.images
  name          = data.docker_registry_image.ghcr_data[each.key].name
  keep_locally  = true
  pull_triggers = [data.docker_registry_image.ghcr_data[each.key].sha256_digest]
}

resource "docker_tag" "tag_for_azure" {
  for_each     = local.images
  source_image = docker_image.ghcr_image[each.key].name
  target_image = "${azurerm_container_registry.phdi_registry.login_server}/phdi/${each.key}:latest"
}

resource "docker_registry_image" "acr_image" {
  for_each      = local.images
  depends_on    = [docker_tag.tag_for_azure]
  name          = "${azurerm_container_registry.phdi_registry.login_server}/phdi/${each.key}:latest"
  keep_remotely = true

  triggers = {
    sha256_digest = data.docker_registry_image.ghcr_data[each.key].sha256_digest
  }
}

##### Container apps #####

resource "azurerm_container_app_environment" "phdi" {
  name                       = terraform.workspace
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_workspace_id
}

resource "azurerm_container_app" "container_app" {
  for_each                     = local.images
  name                         = "phdi-${terraform.workspace}-${each.key}"
  container_app_environment_id = azurerm_container_app_environment.phdi.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.pipeline_runner.id]
  }

  template {
    container {
      name   = "phdi-${terraform.workspace}-${each.key}"
      image  = docker_registry_image.acr_image[each.key].name
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "AUTH_ID"
        value = var.smarty_auth_id
      }
      env {
        name  = "AUTH_TOKEN"
        value = var.smarty_auth_token
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.pipeline_runner.client_id
      }
      env {
        name  = "AZURE_TENANT_ID"
        value = data.azurerm_client_config.current.tenant_id
      }
      env {
        name  = "AZURE_SUBSCRIPTION_ID"
        value = data.azurerm_client_config.current.subscription_id
      }
      env {
        name  = "STORAGE_ACCOUNT_URL"
        value = azurerm_storage_account.phi.primary_blob_endpoint
      }
      env {
        name  = "SALT_STR"
        value = random_uuid.salt.result
      }
      env {
        name  = "COMMUNICATION_SERVICE_NAME"
        value = azurerm_communication_service.communication_service.name
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name  = "phdi-registry-password"
    value = azurerm_container_registry.phdi_registry.admin_password
  }

  registry {
    server               = azurerm_container_registry.phdi_registry.login_server
    username             = azurerm_container_registry.phdi_registry.admin_username
    password_secret_name = "phdi-registry-password"
  }

  lifecycle {
    ignore_changes = [secret]
  }
}

resource "azurerm_container_app_environment_storage" "tabulation_storage" {
  name                         = "phdi${terraform.workspace}tables"
  container_app_environment_id = azurerm_container_app_environment.phdi.id
  account_name                 = azurerm_storage_account.phi.name
  share_name                   = azurerm_storage_share.tables.name
  access_key                   = azurerm_storage_account.phi.primary_access_key
  access_mode                  = "ReadWrite"
}

##### FHIR Server #####

resource "azurerm_healthcare_service" "fhir_server" {
  name                = "${terraform.workspace}fhir${substr(var.client_id, 0, 8)}"
  location            = "eastus"
  resource_group_name = var.resource_group_name
  kind                = "fhir-R4"
  cosmosdb_throughput = 1400

  access_policy_object_ids = [
    azurerm_user_assigned_identity.pipeline_runner.principal_id,
    var.object_id
  ]

  lifecycle {
    ignore_changes = [name, tags]
  }

  tags = {
    environment = terraform.workspace
    managed-by  = "terraform"
  }
}

resource "azurerm_role_assignment" "fhir_contributor" {
  scope                = azurerm_healthcare_service.fhir_server.id
  role_definition_name = "FHIR Data Contributor"
  principal_id         = var.object_id
}

##### User Assigned Identity #####

resource "azurerm_user_assigned_identity" "pipeline_runner" {
  location            = var.location
  name                = "phdi-${terraform.workspace}-pipeline-runner"
  resource_group_name = var.resource_group_name
}

##### Communication Service #####

resource "azurerm_communication_service" "communication_service" {
  name                = "${terraform.workspace}communication${substr(var.client_id, 0, 8)}"
  resource_group_name = var.resource_group_name
  data_location       = "United States"

}

##### Postgres #####

resource "random_password" "postgres_password" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "azurerm_postgresql_flexible_server" "mpi" {
  name                         = "phdi${terraform.workspace}mpi${substr(var.client_id, 0, 8)}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  sku_name                     = "GP_Standard_D2s_v3"
  version                      = "14"
  storage_mb                   = 65536
  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  administrator_login          = "postgres"
  administrator_password       = random_password.postgres_password.result
  tags = {
    environment = terraform.workspace
    managed-by  = "terraform"
  }

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "mpi" {
  name      = "phdi-${terraform.workspace}-dibbs-mpi-db"
  server_id = azurerm_postgresql_flexible_server.mpi.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_virtual_network" "example" {
  name                = "phdi-${terraform.workspace}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "example" {
  name                 = "phdi-${terraform.workspace}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create an Azure Migrate Service
resource "azurerm_database_migration_service" "mpi" {
  name                = "phdi-${terraform.workspace}-dbms"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.example.id
  sku_name            = "Standard_1vCores"
}

# Create an Azure Migrate Project
resource "azurerm_database_migration_project" "mpi" {
  name                = "phdi-${terraform.workspace}-migrate-project"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_name        = azurerm_database_migration_service.mpi.name
}

# # Set up Azure Migrate Server Migration
# resource "azurerm_migrate_assessment" "mpi" {
#   name                = "my-assessment"
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   project_name        = azurerm_migrate_project.mpi.name
# }

# resource "azurerm_migrate_group_map" "mpi" {
#   name                = "my-group-map"
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   project_name        = azurerm_migrate_project.mpi.name
# }

# resource "azurerm_migrate_project_credentials" "mpi" {
#   name                = "my-credentials"
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   project_name        = azurerm_migrate_project.mpi.name
# }

# resource "azurerm_migrate_project_server_assessment" "mpi" {
#   name                = "my-server-assessment"
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   project_name        = azurerm_migrate_project.mpi.name
#   assessment_name     = azurerm_migrate_assessment.mpi.name
#   credentials_name    = azurerm_migrate_project_credentials.mpi.name
# }

# resource "azurerm_migrate_project_server_group_map" "mpi" {
#   name                = "my-server-group-map"
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   project_name        = azurerm_migrate_project.mpi.name
#   assessment_name     = azurerm_migrate_assessment.mpi.name
#   group_map_name      = azurerm_migrate
# }


# provider "postgresql_database" {
#   alias   = "DibbsMpiDB"
#   host    = azurerm_postgresql_flexible_server.mpi.fqdn
#   port    = 5432
#   user    = azurerm_postgresql_flexible_server.mpi.administrator_login
#   password = azurerm_postgresql_flexible_server.mpi.administrator_password
#   database = azurerm_postgresql_flexible_server_database.mpi.name
# }

# resource "postgresql_database_schema" "mpi" {
#   provider = postgresql_database.DibbsMpiDB
#   name     = "my_schema"

#   statement = "CREATE TABLE my_table (id SERIAL PRIMARY KEY, name VARCHAR(50))"
# }

# resource "null_resource" "mpi" {
#   provisioner "local-exec" {
#     command = "curl ifconfig.me"
#     interpreter = ["/bin/bash", "-c"]
#   }

#   # provisioner "local-exec" {
#   #   command = "echo 'public_ip_address = \"${chomp(self.local_exec.output)}\"' > public_ip_address.auto.tfvars"
#   # }

  
# }

# output "public_ip_address" {
#   value               = chomp("${null_resource.mpi.*.triggers.ip_address}")
#   depends_on          = [null_resource.mpi]
# }


# resource "azurerm_postgresql_firewall_rule" "mpi" {
#   name                = "allow-all"
#   resource_group_name = var.resource_group_name
#   server_name         = azurerm_postgresql_flexible_server.mpi.name
#   start_ip_address    = "0.0.0.0"
#   end_ip_address      = "255.255.255.255"
#   depends_on          = [null_resource.mpi]
# }

# resource "null_resource" "setup_tables" {
#   provisioner "local-exec" {
#     command = <<-EOT
#       PGPASSWORD=${azurerm_postgresql_flexible_server.mpi.administrator_password} psql -h ${azurerm_postgresql_flexible_server.mpi.fqdn} -U ${azurerm_postgresql_flexible_server.mpi.administrator_login} -d ${azurerm_postgresql_flexible_server_database.mpi.name} -f "../../scripts/dibbs_mp_db.ddl"
#     EOT
#   }

#   depends_on = [
#     azurerm_postgresql_flexible_server_database.mpi,
#     azurerm_postgresql_firewall_rule.mpi
#   ]
# }