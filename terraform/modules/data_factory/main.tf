resource "azurerm_data_factory" "phdi_data_factory" {
  name                            = "phdi-${terraform.workspace}-data-factory"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  public_network_enabled          = false
  managed_virtual_network_enabled = true

  identity {
    type = "SystemAssigned"
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
  ingestion-pipeline-config = jsondecode(file("../modules/data_factory/ingestion-pipeline.json"))
}

resource "azurerm_data_factory_pipeline" "phdi_ingestion" {
  name            = "phdi-ingestion"
  data_factory_id = azurerm_data_factory.phdi_data_factory.id
  concurrency     = 10 // Max concurrent instances of the pipeline, between 1 and 50. May need to tune this in the future. 
  parameters = jsonencode(local.ingestion-pipeline-config.properties.parameters)
  activities_json = jsonencode(local.ingestion-pipeline-config.properties.activities)
}