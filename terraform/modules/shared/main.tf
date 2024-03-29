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

resource "azurerm_storage_queue" "source_data_queue" {
  name                 = "sourcedataqueue"
  storage_account_name = azurerm_storage_account.phi.name
}

resource "azurerm_storage_queue" "staging_queue" {
  name                 = "stagingqueue"
  storage_account_name = azurerm_storage_account.phi.name
}

resource "azurerm_storage_data_lake_gen2_filesystem" "source_data" {
  name               = "source-data"
  storage_account_id = azurerm_storage_account.phi.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "bundle_snapshots" {
  name               = "bundle-snapshots"
  storage_account_id = azurerm_storage_account.phi.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "linkage_notebook_outputs" {
  name               = "linkage-notebook-outputs"
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

resource "azurerm_storage_blob" "fhir" {
  name                   = "fhir/.keep"
  storage_account_name   = azurerm_storage_account.phi.name
  storage_container_name = azurerm_storage_data_lake_gen2_filesystem.source_data.name
  type                   = "Block"
  source_content         = ""
}

resource "azurerm_storage_blob" "covid-identification-config" {
  name                   = "covid_identification_config.json"
  storage_account_name   = azurerm_storage_account.phi.name
  storage_container_name = azurerm_storage_data_lake_gen2_filesystem.delta-tables.name
  type                   = "Block"
  source_content         = file("../../scripts/Synapse/config/covid_identification_config.json")
}

resource "azurerm_storage_blob" "ecr-datastore-config" {
  name                   = "ecr_datastore_config.json"
  storage_account_name   = azurerm_storage_account.phi.name
  storage_container_name = azurerm_storage_data_lake_gen2_filesystem.delta-tables.name
  type                   = "Block"
  source_content         = file("../../scripts/Synapse/config/ecr_datastore_config.json")
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

resource "azurerm_storage_container" "patient_data_container_name" {
  name                 = "patient-data"
  storage_account_name = azurerm_storage_account.phi.name
}

resource "azurerm_storage_data_lake_gen2_filesystem" "delta-tables" {
  name               = "delta-tables"
  storage_account_id = azurerm_storage_account.phi.id
}

resource "azurerm_role_assignment" "phi_storage_contributor" {
  scope                = azurerm_storage_account.phi.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.pipeline_runner.principal_id
}

resource "azurerm_role_assignment" "phi_queue_contributor" {
  scope                = azurerm_storage_account.phi.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_user_assigned_identity.pipeline_runner.principal_id
}

resource "azurerm_storage_share" "custom_schemas" {
  name                 = "phdi${terraform.workspace}customschemas"
  storage_account_name = azurerm_storage_account.phi.name
  quota                = 50
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

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_synapse_workspace.phdi.identity.0.principal_id

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

resource "azurerm_key_vault_secret" "mpi_db_password" {
  name         = "mpi-db-password"
  value        = azurerm_postgresql_flexible_server.mpi.administrator_password
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

resource "azurerm_key_vault_secret" "phi_storage_account_name" {
  name         = "phi-storage-account-name"
  value        = azurerm_storage_account.phi.name
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

resource "azurerm_key_vault_secret" "record_linkage_url" {
  name         = "record-linkage-url"
  value        = "https://phdi-${terraform.workspace}-record-linkage.${azurerm_container_app_environment.phdi.default_domain}"
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

resource "azurerm_key_vault_secret" "ingestion-url" {
  name         = "ingestion-url"
  value        = "https://phdi-${terraform.workspace}-ingestion.${azurerm_container_app_environment.phdi.default_domain}"
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

resource "azurerm_key_vault_secret" "message-parser-url" {
  name         = "message-parser-url"
  value        = "https://phdi-${terraform.workspace}-parse_message.${azurerm_container_app_environment.phdi.default_domain}"
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
    "message-parser",
    "validation",
    "record-linkage",
  ])

  phdi_version = "v1.1.7"
}

data "docker_registry_image" "ghcr_data" {
  for_each = local.images
  name     = "ghcr.io/cdcgov/phdi/${each.key}:${local.phdi_version}"
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
  target_image = "${azurerm_container_registry.phdi_registry.login_server}/phdi/${each.key}:${local.phdi_version}"
}

resource "docker_registry_image" "acr_image" {
  for_each      = local.images
  depends_on    = [docker_tag.tag_for_azure]
  name          = "${azurerm_container_registry.phdi_registry.login_server}/phdi/${each.key}:${local.phdi_version}"
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
  special          = false
  override_special = "!#$%&*()-_=+[]{}<>:?"
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
    max_replicas = 200
    min_replicas = 0
    container {
      name   = "phdi-${terraform.workspace}-${each.key}"
      image  = docker_registry_image.acr_image[each.key].name
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "SMARTY_AUTH_ID"
        value = var.smarty_auth_id
      }
      env {
        name  = "SMARTY_AUTH_TOKEN"
        value = var.smarty_auth_token
      }
      env {
        name  = "SMARTY_LICENSE_TYPE"
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
        name  = "MPI_DB_TYPE"
        value = "postgres"
      }
      env {
        name  = "MPI_PASSWORD"
        value = azurerm_postgresql_flexible_server.mpi.administrator_password
      }
      env {
        name  = "MPI_USER"
        value = azurerm_postgresql_flexible_server.mpi.administrator_login
      }
      env {
        name  = "MPI_PORT"
        value = "5432"
      }
      env {
        name  = "MPI_HOST"
        value = azurerm_postgresql_flexible_server.mpi.fqdn
      }
      env {
        name  = "MPI_DBNAME"
        value = azurerm_postgresql_flexible_server_database.mpi.name
      }
      env {
        name  = "MPI_PATIENT_TABLE"
        value = "patient"
      }
      env {
        name  = "MPI_PERSON_TABLE"
        value = "person"
      }

      dynamic "volume_mounts" {
        for_each = each.key == "message-parser" ? [1] : []
        content {
          name = azurerm_storage_share.custom_schemas.name
          path = "/code/app/custom_schemas"
        }
      }
    }

    dynamic "volume" {
      for_each = each.key == "message-parser" ? [1] : []
      content {
        name         = azurerm_storage_share.custom_schemas.name
        storage_type = "AzureFile"
        storage_name = azurerm_container_app_environment_storage.custom_schema_storage.name
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

resource "azurerm_container_app_environment_storage" "custom_schema_storage" {
  name                         = "phdi${terraform.workspace}customschemas"
  container_app_environment_id = azurerm_container_app_environment.phdi.id
  account_name                 = azurerm_storage_account.phi.name
  share_name                   = azurerm_storage_share.custom_schemas.name
  access_key                   = azurerm_storage_account.phi.primary_access_key
  access_mode                  = "ReadWrite"
}

##### FHIR Server #####

resource "azurerm_healthcare_workspace" "fhir_server" {
  name                = "${terraform.workspace}${substr(var.client_id, 0, 8)}"
  location            = "westus2"
  resource_group_name = var.resource_group_name
}

resource "azurerm_healthcare_fhir_service" "fhir_server" {
  name                = "fhir-server"
  location            = "westus2"
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_healthcare_workspace.fhir_server.id
  kind                = "fhir-R4"

  authentication {
    authority = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}"
    audience  = "https://${terraform.workspace}${substr(var.client_id, 0, 8)}-fhir-server.fhir.azurehealthcareapis.com"
  }

  cors {
    allowed_origins     = ["https://${azurerm_container_app.container_app["ingestion"].latest_revision_fqdn}"]
    allowed_headers     = ["*"]
    allowed_methods     = ["GET", "DELETE", "PUT", "POST"]
    max_age_in_seconds  = 3600
    credentials_allowed = true
  }

  lifecycle {
    ignore_changes = [name, tags]
  }

  tags = {
    environment = terraform.workspace
    managed-by  = "terraform"
  }
}

resource "azurerm_role_assignment" "gh_sp_fhir_contributor" {
  scope                = azurerm_healthcare_fhir_service.fhir_server.id
  role_definition_name = "FHIR Data Contributor"
  principal_id         = var.object_id
}

resource "azurerm_role_assignment" "pipeline_runner_fhir_contributor" {
  scope                = azurerm_healthcare_fhir_service.fhir_server.id
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
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.delta-tables.id
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
  name                                = "sparkpool"
  synapse_workspace_id                = azurerm_synapse_workspace.phdi.id
  node_size_family                    = "MemoryOptimized"
  node_size                           = "Small"
  cache_size                          = 100
  spark_version                       = 3.3
  dynamic_executor_allocation_enabled = true
  min_executors                       = 1
  max_executors                       = 2

  auto_scale {
    max_node_count = 50
    min_node_count = 3
  }

  auto_pause {
    delay_in_minutes = 15
  }

  library_requirement {
    content  = <<EOF
azure-identity
phdi
recordlinkage
azure-keyvault-secrets
EOF
    filename = "requirements.txt"
  }

  spark_config {
    content  = <<EOF
spark.kryoserializer.buffer.max 512
spark.serializer org.apache.spark.serializer.KryoSerializer
EOF
    filename = "sparkpoolconfig.txt"
  }
}

resource "azurerm_synapse_firewall_rule" "synapse_firewall_rule" {
  name                 = "AllowAll"
  synapse_workspace_id = azurerm_synapse_workspace.phdi.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "255.255.255.255"
}

resource "azurerm_role_assignment" "synapse_blob_contributor" {
  scope                = azurerm_storage_account.phi.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.phdi.identity[0].principal_id
}

resource "azuread_application" "synapse_app" {
  display_name = "phdi-${terraform.workspace}-synapse-${substr(var.client_id, 0, 8)}"
}

resource "azuread_application_password" "synapse_app_password" {
  application_object_id = azuread_application.synapse_app.object_id
}

resource "azurerm_key_vault_secret" "synapse_client_secret" {
  name         = "synapse-client-secret"
  value        = azuread_application_password.synapse_app_password.value
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

resource "azurerm_key_vault_secret" "synapse_client_id" {
  name         = "synapse-client-id"
  value        = azuread_application.synapse_app.application_id
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

resource "azurerm_synapse_linked_service" "synapse_linked_service_key_vault" {
  name                 = "${terraform.workspace}${substr(var.client_id, 0, 8)}-keyvault-linked-service"
  synapse_workspace_id = azurerm_synapse_workspace.phdi.id
  type                 = "AzureKeyVault"
  type_properties_json = <<JSON
  {
  "baseUrl": "https://${terraform.workspace}vault${substr(var.client_id, 0, 8)}.vault.azure.net/"
  }
  JSON
}

resource "azurerm_synapse_linked_service" "synapse_linked_service_blob_storage" {
  name                 = "phdi${terraform.workspace}${substr(var.client_id, 0, 8)}-blob-storage-linked-service"
  synapse_workspace_id = azurerm_synapse_workspace.phdi.id
  type                 = "AzureBlobStorage"
  type_properties_json = <<JSON
  {
  "serviceEndpoint": "https://phdi${terraform.workspace}phi${substr(var.client_id, 0, 8)}.blob.core.windows.net/",
  "accountKind": "StorageV2"
  }
  JSON
}
