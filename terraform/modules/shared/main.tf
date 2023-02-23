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

  network_rules {
    default_action             = "Deny"
    bypass                     = ["None"]
    virtual_network_subnet_ids = [azurerm_subnet.phdi.id]
    ip_rules                   = [data.http.runner_ip.response_body]
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

  network_acls {
    default_action             = "Deny"
    bypass                     = "None"
    virtual_network_subnet_ids = [azurerm_subnet.phdi.id]
    ip_rules                   = [data.http.runner_ip.response_body]
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
  name                       = "phdi${terraform.workspace}registry${substr(var.client_id, 0, 8)}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  sku                        = "Premium"
  admin_enabled              = true
  network_rule_bypass_option = "None"

  network_rule_set {
    default_action = "Deny"
    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.phdi.id
    }
    ip_rule {
      action   = "Allow"
      ip_range = "${data.http.runner_ip.response_body}/32"
    }
  }
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
    "hapi"
  ])
}

data "docker_registry_image" "ghcr_data" {
  for_each = local.images
  name     = each.key == "hapi" ? "hapiproject/hapi:latest" : "ghcr.io/cdcgov/phdi/${each.key}:main"
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

##### Virual network #####

resource "azurerm_virtual_network" "phdi" {
  name                = "phdi-${terraform.workspace}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "phdi" {
  name                 = "phdi-${terraform.workspace}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.phdi.name
  address_prefixes     = ["10.0.0.0/21"]

  service_endpoints = [
    "Microsoft.Sql",
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.ContainerRegistry",
    "Microsoft.EventHub",
    "Microsoft.Web",
  ]

  delegation {
    name = "functionapp"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  delegation {
    name = "containerapp"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  delegation {
    name = "postgresql"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/singleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "postgres.database.azure.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "phdi-${terraform.workspace}-postgres-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.phdi.id
}

##### Container apps #####

resource "azurerm_container_app_environment" "phdi" {
  name                           = terraform.workspace
  location                       = var.location
  resource_group_name            = var.resource_group_name
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  infrastructure_subnet_id       = azurerm_subnet.phdi.id
  internal_load_balancer_enabled = true
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
      env {
        name  = "SPRING_DATASOURCE_URL"
        value = "jdbc:postgresql://${azurerm_postgresql_server.postgres.fqdn}/${azurerm_postgresql_database.hapi.name}"
      }
      env {
        name  = "SPRING_DATASOURCE_USERNAME"
        value = "${azurerm_postgresql_server.postgres.administrator_login}@${azurerm_postgresql_server.postgres.name}"
      }
      env {
        name  = "SPRING_DATASOURCE_PASSWORD"
        value = azurerm_postgresql_server.postgres.administrator_login_password
      }
      env {
        name  = "SPRING_DATASOURCE_DRIVER_CLASS_NAME"
        value = "org.postgresql.Driver"
      }
    }
  }

  ingress {
    external_enabled = false
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
}

resource "azurerm_container_app_environment_storage" "tabulation_storage" {
  name                         = "phdi${terraform.workspace}tables"
  container_app_environment_id = azurerm_container_app_environment.phdi.id
  account_name                 = azurerm_storage_account.phi.name
  share_name                   = azurerm_storage_share.tables.name
  access_key                   = azurerm_storage_account.phi.primary_access_key
  access_mode                  = "ReadWrite"
}

##### HAPI FHIR Server Database #####

resource "random_password" "postgres_password" {
  length  = 20
  special = true
}

resource "azurerm_postgresql_server" "postgres" {
  name                = "phdi${terraform.workspace}postgres"
  location            = var.location
  resource_group_name = var.resource_group_name

  administrator_login          = "phdi"
  administrator_login_password = random_password.postgres_password.result

  sku_name   = "GP_Gen5_2"
  version    = "11"
  storage_mb = 102400

  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  public_network_access_enabled = false
  ssl_enforcement_enabled       = true
}

resource "azurerm_postgresql_database" "hapi" {
  name                = "hapi"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.postgres.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_private_endpoint" "postgres" {
  name                = "phdi${terraform.workspace}postgres"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.phdi.id

  private_service_connection {
    name                           = "phdi${terraform.workspace}postgres-psc"
    private_connection_resource_id = azurerm_postgresql_server.postgres.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "phdi${terraform.workspace}postgres-pdzg"
    private_dns_zone_ids = [azurerm_private_dns_zone.postgres.id]
  }
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
