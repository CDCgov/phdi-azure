output "phdi_data_factory_name" {
  value = azurerm_data_factory.phdi_data_factory.name
}

output "ingestion_pipeline_name" {
  value = azurerm_data_factory_pipeline.phdi_ingestion.name
}

output "kafka_to_delta_pipeline_name" {
  value = azurerm_data_factory_pipeline.phdi_kafka_to_delta_table_pipeline.name
}
