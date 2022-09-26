resource "azurerm_storage_account" "testbucket" {
  name                     = "phdi-testbucket-${var.subscription_id}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "GRS"

  lifecycle {
    prevent_destroy = false
  }
}
