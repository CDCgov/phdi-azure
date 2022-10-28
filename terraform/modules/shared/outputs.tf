output "phi_storage_account_connection_string" {
  value = azurerm_storage_account.phi.primary_connection_string
}

output "ingestion_queue_name" {
  value = azurerm_servicebus_queue.ingestion.name
}

output "service_bus_connection_string" {
  value = azurerm_servicebus_namespace.ingestion.default_primary_connection_string
}

output "function_app_storage_account_name" {
  value = azurerm_storage_account.function_app_sa.name
}

output "function_app_storage_account_access_key" {
  value = azurerm_storage_account.function_app_sa.primary_access_key
}

output "function_app_storage_account_connection_string" {
  value = azurerm_storage_account.function_app_sa.primary_connection_string
}

output "function_app_service_plan_id" {
  value = azurerm_service_plan.function_app_sp.id
}

output "container_registry_url" {
  value = azurerm_container_registry.phdi_registry.login_server
}

output "container_registry_reader_id" {
  value = azurerm_user_assigned_identity.registry_reader.client_id
}

output "application_insights_instrumentation_key" {
  value = azurerm_application_insights.insights.instrumentation_key
}
