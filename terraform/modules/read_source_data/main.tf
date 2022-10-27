data "archive_file" "read_source_data" {
  type        = "zip"
  source_dir  = "../../serverless-functions"
  output_path = "function-app.zip"
}

resource "azurerm_storage_container" "read_source_data" {
  name                 = "read-source-data"
  storage_account_name = var.function_app_storage_account_name
}

resource "azurerm_storage_blob" "read_source_data_blob" {
  name                   = "${filesha256(data.archive_file.read_source_data.output_path)}.zip"
  storage_account_name   = var.function_app_storage_account_name
  storage_container_name = azurerm_storage_container.read_source_data.name
  type                   = "Block"
  source                 = data.archive_file.read_source_data.output_path
}

data "azurerm_storage_account_blob_container_sas" "storage_account_blob_container_sas" {
  connection_string = var.function_app_storage_account_connection_string
  container_name    = azurerm_storage_container.read_source_data.name

  start  = "2021-01-01T00:00:00Z"
  expiry = "2026-01-01T00:00:00Z"

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
}

resource "azurerm_linux_function_app" "read_source_data" {
  name                       = "phdi-${terraform.workspace}-read-source-data"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  service_plan_id            = var.function_app_service_plan_id
  storage_account_name       = var.function_app_storage_account_name
  storage_account_access_key = var.function_app_storage_account_access_key

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE        = 1
    FUNCTIONS_WORKER_RUNTIME        = "python"
    SCM_DO_BUILD_DURING_DEPLOYMENT  = 1
    AzureWebJobsPhiStorage          = var.phi_storage_account_connection_string
    AzureServiceBusConnectionString = var.service_bus_connection_string
    ServiceBusQueueName             = var.ingestion_queue_name
    APPINSIGHTS_INSTRUMENTATIONKEY  = azurerm_application_insights.insights.instrumentation_key
  }

  site_config {
    application_stack {
      python_version = "3.9"
    }
  }
}
