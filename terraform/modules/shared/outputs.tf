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

output "fhir_converter_url" {
  value = azurerm_container_app.container_app["fhir-converter"].latest_revision_fqdn
}

output "ingestion_container_url" {
  value = azurerm_container_app.container_app["ingestion"].latest_revision_fqdn
}

# TODO: Uncomment when tabulation is implemented
# output "tabulation_container_url" {
#   value = azurerm_container_app.container_app["tabulation"].latest_revision_fqdn
# }

# TODO: Uncomment when alerts are implemented
# output "alerts_container_url" {
#   value = azurerm_container_app.container_app["alerts"].latest_revision_fqdn
# }
