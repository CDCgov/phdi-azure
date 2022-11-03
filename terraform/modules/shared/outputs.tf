output "phi_storage_account_connection_string" {
  value = azurerm_storage_account.phi.primary_connection_string
}

output "ingestion_queue_name" {
  value = azurerm_servicebus_queue.ingestion.name
}

output "service_bus_connection_string" {
  value = azurerm_servicebus_namespace.ingestion.default_primary_connection_string
}

output "fhir_server_name" {
  value = azurerm_healthcare_service.fhir_server.name
}

variable "subscription_id" {
  value = var.subscription_id
}
