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
    hapi_container_url                      = var.hapi_container_url,
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

resource "azurerm_private_dns_zone" "data_factory" {
  name                = "privatelink.datafactory.azure.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "data_factory" {
  name                  = "phdi-${terraform.workspace}-datafactory-privatelink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.data_factory.name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_endpoint" "data_factory" {
  name                = "phdi-${terraform.workspace}-datafactory-private-endpoint"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "phdi-${terraform.workspace}-datafactory-private-endpoint-psc"
    private_connection_resource_id = azurerm_data_factory.phdi_data_factory.id
    subresource_names              = ["dataFactory"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "phdi-${terraform.workspace}-datafactory-private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.data_factory.id]
  }
}
