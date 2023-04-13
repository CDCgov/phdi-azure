##### PHI Storage Account #####

resource "azurerm_storage_account" "phi" {
  name                     = "phdi${terraform.workspace}phi${substr(var.client_id, 0, 8)}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "GRS"
  is_hns_enabled           = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.pipeline_runner.id]
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "source_data" {
  name               = "source-data"
  storage_account_id = azurerm_storage_account.phi.id
}

resource "azurerm_storage_blob" "vxu" {
  name                   = "vxu/.keep"
  storage_account_name   = azurerm_storage_account.phi.name
  storage_container_name = azurerm_storage_data_lake_gen2_filesystem.source_data.name
  type                   = "Block"
  source_content         = ""
}

resource "azurerm_storage_blob" "ecr" {
  name                   = "ecr/.keep"
  storage_account_name   = azurerm_storage_account.phi.name
  storage_container_name = azurerm_storage_data_lake_gen2_filesystem.source_data.name
  type                   = "Block"
  source_content         = ""
}

resource "azurerm_storage_blob" "elr" {
  name                   = "elr/.keep"
  storage_account_name   = azurerm_storage_account.phi.name
  storage_container_name = azurerm_storage_data_lake_gen2_filesystem.source_data.name
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

resource "azurerm_storage_container" "validation_failures_container_name" {
  name                 = "validation-failures"
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
    "record-linkage"
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

resource "azurerm_postgresql_flexible_server_configuration" "mpi" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.mpi.id
  value     = "UUID-OSSP"
}

resource "azurerm_postgresql_flexible_server_database" "mpi" {
  name      = "DibbsMpiDB"
  server_id = azurerm_postgresql_flexible_server.mpi.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

// Allow Azure services to access the database
// See here: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_firewall_rule
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "allow_azure_services"
  server_id        = azurerm_postgresql_flexible_server.mpi.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
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
        name  = "LICENSE_TYPE"
        value = var.smarty_license_type
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
      env {
        name  = "DB_USER"
        value = "postgres"
      }
      env {
        name  = "DB_PASSWORD"
        value = random_password.postgres_password.result
      }
      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.mpi.fqdn
      }
      env {
        name  = "DB_NAME"
        value = azurerm_postgresql_flexible_server_database.mpi.name
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
  cosmosdb_throughput = 400

  lifecycle {
    ignore_changes = [name, tags]
  }

  tags = {
    environment = terraform.workspace
    managed-by  = "terraform"
  }
}

resource "azurerm_role_assignment" "gh_sp_fhir_contributor" {
  scope                = azurerm_healthcare_service.fhir_server.id
  role_definition_name = "FHIR Data Contributor"
  principal_id         = var.object_id
}

resource "azurerm_role_assignment" "pipeline_runner_fhir_contributor" {
  scope                = azurerm_healthcare_service.fhir_server.id
  role_definition_name = "FHIR Data Contributor"
  principal_id         = azurerm_user_assigned_identity.pipeline_runner.principal_id
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


##### Event Hub #####

resource "azurerm_eventhub_namespace" "phdi" {
  name                = "phdi${terraform.workspace}evhns${substr(var.client_id, 0, 8)}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  capacity            = 1

  tags = {
    environment = terraform.workspace
    managed-by  = "terraform"
  }
}

resource "azurerm_eventhub" "phdi" {
  name                = "phdi${terraform.workspace}evh${substr(var.client_id, 0, 8)}"
  namespace_name      = azurerm_eventhub_namespace.phdi.name
  resource_group_name = var.resource_group_name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_role_assignment" "event_hub_contributor" {
  scope                = azurerm_eventhub_namespace.phdi.id
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = azurerm_user_assigned_identity.pipeline_runner.principal_id
}

resource "azurerm_role_assignment" "service_bus_contributor" {
  scope                = azurerm_eventhub_namespace.phdi.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_user_assigned_identity.pipeline_runner.principal_id
}


##### Synapse #####

resource "random_password" "synapse_sql_password" {
  length           = 32
  special          = true
  override_special = "_%@"
}

# Store password in key vault
resource "azurerm_key_vault_secret" "synapse_sql_password" {
  name         = "synapse-sql-password"
  value        = random_password.synapse_sql_password.result
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

resource "azurerm_synapse_workspace" "phdi" {
  name                                 = "phdi${terraform.workspace}synapse${substr(var.client_id, 0, 8)}"
  resource_group_name                  = var.resource_group_name
  location                             = var.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.source_data.id
  sql_administrator_login              = "sqladminuser"
  sql_administrator_login_password     = random_password.synapse_sql_password.result

  identity {
    type = "SystemAssigned, UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.pipeline_runner.id
    ]
  }
}

resource "azurerm_synapse_spark_pool" "phdi" {
  name                 = "${terraform.workspace}pool"
  synapse_workspace_id = azurerm_synapse_workspace.phdi.id
  node_size_family     = "MemoryOptimized"
  node_size            = "Small"
  cache_size           = 100
  spark_version        = 3.3

  auto_scale {
    max_node_count = 50
    min_node_count = 3
  }

  auto_pause {
    delay_in_minutes = 15
  }

  spark_config {
    content  = <<EOF
spark.shuffle.spill                true
EOF
    filename = "config.txt"
  }
}
