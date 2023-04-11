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

output "pipeline_runner_resource_id" {
  value = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourcegroups/${var.resource_group_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${azurerm_user_assigned_identity.pipeline_runner.name}"
}

output "fhir_upload_failures_container_name" {
  value = azurerm_storage_container.fhir_upload_failures_container_name.name
}

output "validation_failures_container_name" {
  value = azurerm_storage_container.validation_failures_container_name.name
}

output "fhir_conversion_failures_container_name" {
  value = azurerm_storage_container.fhir_conversion_failures_container_name.name
}

output "fhir_converter_url" {
  value = "https://phdi-${terraform.workspace}-fhir-converter.${azurerm_container_app_environment.phdi.default_domain}"
}

output "ingestion_container_url" {
  value = "https://phdi-${terraform.workspace}-ingestion.${azurerm_container_app_environment.phdi.default_domain}"
}

output "message_parser_url" {
  value = "https://phdi-${terraform.workspace}-message-parser.${azurerm_container_app_environment.phdi.default_domain}"
}

output "validation_container_url" {
  value = "https://phdi-${terraform.workspace}-validation.${azurerm_container_app_environment.phdi.default_domain}"
}

output "record_linkage_container_url" {
  value = "https://phdi-${terraform.workspace}-record-linkage.${azurerm_container_app_environment.phdi.default_domain}"
}

# TODO: Uncomment when tabulation is implemented
# output "tabulation_container_url" {
#   value = "https://phdi-${terraform.workspace}-tabulation.${azurerm_container_app_environment.phdi.default_domain}"
# }

# TODO: Uncomment when alerts are implemented
# output "alerts_container_url" {
#   value = "https://phdi-${terraform.workspace}-alerts.${azurerm_container_app_environment.phdi.default_domain}"
# }

output "eventhub_namespace_name" {
  value = azurerm_eventhub_namespace.phdi.name
}

output "eventhub_name" {
  value = azurerm_eventhub.phdi.name
}
