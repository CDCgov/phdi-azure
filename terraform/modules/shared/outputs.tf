output "phi_storage_account_endpoint_url" {
  value = azurerm_storage_account.phi.primary_blob_endpoint
}

output "phi_storage_account_key" {
  value = azurerm_storage_account.phi.primary_access_key
}

output "fhir_server_name" {
  value = azurerm_healthcare_service.fhir_server.name
}

output "pipeline_runner_id" {
  value = azurerm_user_assigned_identity.pipeline_runner.id
}

output "pipeline_runner_client_id" {
  value = azurerm_user_assigned_identity.pipeline_runner.client_id
}

output "pipeline_runner_principal_id" {
  value = azurerm_user_assigned_identity.pipeline_runner.principal_id
}

output "fhir_upload_failures_container_name" {
  value = azurerm_storage_container.fhir_upload_failures_container_name.name
}

output "fhir_conversion_failures_container_name" {
  value = azurerm_storage_container.fhir_conversion_failures_container_name.name
}
