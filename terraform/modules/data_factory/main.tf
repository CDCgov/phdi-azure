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

resource "azurerm_role_assignment" "data_factory_contributor" {
  scope                = azurerm_data_factory.phdi_data_factory.id
  role_definition_name = "Contributor"
  principal_id         = var.pipeline_runner_principal_id
}

resource "null_resource" "adf_credential" {
  provisioner "local-exec" {
    command = <<-EOT
      # Get an access token for Azure Management API
      access_token=$(az account get-access-token --query 'accessToken' -o tsv)

      # Define the credential JSON payload
      credential_payload=$(cat <<-JSON
      {
        "properties": {
          "type": "ManagedIdentity",
          "typeProperties": {
            "resourceId": "${var.pipeline_runner_resource_id}"
          }
        }
      }
      JSON
      )

      # Create the credential in Azure Data Factory
      az rest --method put \
        --uri "https://management.azure.com/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.DataFactory/factories/${azurerm_data_factory.phdi_data_factory.name}/credentials/pipeline-runner-credential?api-version=2018-06-01" \
        --headers "Content-Type=application/json" \
        --headers "Authorization=Bearer $access_token" \
        --body "$credential_payload"
    EOT
  }

  depends_on = [azurerm_data_factory.phdi_data_factory, azurerm_role_assignment.data_factory_contributor]
}

locals {
  ingestion-pipeline-config = jsondecode(templatefile("../modules/data_factory/ingestion-pipeline.json", {
    validation_container_url                = var.validation_container_url,
    environment                             = terraform.workspace,
    fhir_converter_url                      = var.fhir_converter_url,
    ingestion_container_url                 = var.ingestion_container_url,
    message_parser_url                      = var.message_parser_url,
    storage_account_url                     = var.phi_storage_account_endpoint_url,
    validation_failures_container_name      = var.validation_failures_container_name,
    fhir_upload_failures_container_name     = var.fhir_upload_failures_container_name,
    fhir_conversion_failures_container_name = var.fhir_conversion_failures_container_name,
    record_linkage_container_url            = var.record_linkage_container_url,
    delta_tables_container_name             = var.delta_tables_container_name
  }))
  pipeline-metrics-dashboard-config = jsondecode(templatefile("../modules/data_factory/pipeline-metrics-dashboard.json", {
    data_factory_id = azurerm_data_factory.phdi_data_factory.id,
    environment     = terraform.workspace,
  }))
}

resource "azurerm_data_factory_pipeline" "phdi_ingestion" {
  name            = "phdi-${terraform.workspace}-ingestion"
  data_factory_id = azurerm_data_factory.phdi_data_factory.id
  parameters = {
    "filename" : "",
    "message" : "",
    "message_type" : "",
    "root_template" : "",
    "include_error_types" : ""
  }

  activities_json = jsonencode(local.ingestion-pipeline-config.properties.activities)

  depends_on = [null_resource.adf_credential]
}

##### Pipeline metrics dashboard #####

resource "azurerm_portal_dashboard" "pipeline_metrics" {
  name                = "pipeline-metrics-${terraform.workspace}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags = {
    source = "terraform"
  }

  dashboard_properties = jsonencode(local.pipeline-metrics-dashboard-config.properties)
}
