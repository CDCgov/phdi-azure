output "phi_storage_account_endpoint_url" {
  value = azurerm_storage_account.phi.primary_blob_endpoint
}

output "phi_storage_account_key" {
  value = azurerm_storage_account.phi.primary_access_key
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
  value = "https://phdi-${terraform.workspace}-fhir-converter.${azurerm_container_app_environment.phdi.default_domain}"
}

output "ingestion_container_url" {
  value = "https://phdi-${terraform.workspace}-ingestion.${azurerm_container_app_environment.phdi.default_domain}"
}

output "hapi_container_url" {
  value = "https://phdi-${terraform.workspace}-hapi.${azurerm_container_app_environment.phdi.default_domain}"
}

# TODO: Uncomment when tabulation is implemented
# output "tabulation_container_url" {
#   value = "https://phdi-${terraform.workspace}-tabulation.${azurerm_container_app_environment.phdi.default_domain}"
# }

# TODO: Uncomment when alerts are implemented
# output "alerts_container_url" {
#   value = "https://phdi-${terraform.workspace}-alerts.${azurerm_container_app_environment.phdi.default_domain}"
# }

output "subnet_id" {
  value = azurerm_subnet.phdi.id
}

output "functionapp_subnet_id" {
  value = azurerm_subnet.functionapp.id
}

output "eventhub_namespace_name" {
  value = azurerm_eventhub_namespace.evhns.name
}

output "eventhub_name" {
  value = azurerm_eventhub.evh.name
}
