##### PHI Storage Account #####

resource "azurerm_storage_account" "phi" {
  name                     = "phdi${terraform.workspace}phi"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "GRS"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "source_data" {
  name                 = "source-data"
  storage_account_name = azurerm_storage_account.phi.name
}

##### Service Bus #####

resource "azurerm_servicebus_namespace" "ingestion" {
  name                = "phdi-${terraform.workspace}-ingestion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
}

resource "azurerm_servicebus_queue" "ingestion" {
  name         = "phdi-${terraform.workspace}-ingestion"
  namespace_id = azurerm_servicebus_namespace.ingestion.id

  enable_partitioning = true
}

##### Key Vault #####

resource "azurerm_key_vault" "phdi_key_vault" {
  name                       = "phdi-key-vault"
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
}

resource "random_uuid" "salt" {}

resource "azurerm_key_vault_secret" "salt" {
  name         = "patient-hash-salt"
  value        = random_uuid.salt.result
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

##### Container registry #####

resource "azurerm_container_registry" "phdi_registry" {
  name                = "phdi${terraform.workspace}registry"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Premium"
}
