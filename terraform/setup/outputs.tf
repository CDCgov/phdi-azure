output "state_bucket_name" {
  value = azurerm_storage_account.tfstate.id
}
