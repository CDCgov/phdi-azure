resource "azurerm_data_factory" "phdi_data_factory" {
  name                            = "phdi-${terraform.workspace}-data-factory-${substr(var.client_id, 0, 8)}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  public_network_enabled          = false
  managed_virtual_network_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [var.pipeline_runner_id]
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  tags = {
    environment = terraform.workspace
    managed-by  = "terraform"
  }
}
locals {
  ingestion-pipeline-config = jsondecode(templatefile("../modules/data_factory/ingestion-pipeline.json", {
    fhir_converter_url                      = var.fhir_converter_url,
    ingestion_container_url                 = var.ingestion_container_url,
    fhir_server_url                         = var.fhir_server_url,
    storage_account_url                     = var.phi_storage_account_endpoint_url,
    fhir_upload_failures_container_name     = var.fhir_upload_failures_container_name,
    fhir_conversion_failures_container_name = var.fhir_conversion_failures_container_name,
  }))
}

resource "azurerm_data_factory_pipeline" "phdi_ingestion" {
  name            = "phdi-${terraform.workspace}-ingestion"
  data_factory_id = azurerm_data_factory.phdi_data_factory.id
  concurrency     = 10 // Max concurrent instances of the pipeline, between 1 and 50. May need to tune this in the future. 
  parameters = {
    "filename" : "",
    "message" : "",
    "message_type" : "",
    "root_template" : "",
  }

  activities_json = jsonencode(local.ingestion-pipeline-config.properties.activities)
}

resource "azurerm_role_assignment" "data_factory_contributor" {
  scope                = azurerm_data_factory.phdi_data_factory.id
  role_definition_name = "Contributor"
  principal_id         = var.pipeline_runner_principal_id
}
