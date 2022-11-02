output "adf_identity_id" {
  value = azurerm_data_factory.phdi_data_factory.identity[0].principal_id
}
