output "phi_storage_account_connection_string" {
  value = azurerm_storage_account.phi.primary_connection_string
}

output "phi_storage_account_endpoint_url" {
  value = azurerm_storage_account.phi.primary_blob_endpoint
}

output "fhir_server_name" {
  value = azurerm_healthcare_service.fhir_server.name
}

output "time_stamp" {
  value = tostring(time_static.timestamp.unix)
}

output "pipeline_runner_id" {
  value = azurerm_user_assigned_identity.pipeline_runner.id
}

output "pipeline_runner_client_id" {
  value = azurerm_user_assigned_identity.pipeline_runner.client_id
}
