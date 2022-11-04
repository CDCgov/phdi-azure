output "phi_adf_name" {
  value = azurerm_data_factory.phdi_data_factory.name
}

output "ingestion_pipeline_name" {
  value = azurerm_data_factory_pipeline.phdi_ingestion.name
}
