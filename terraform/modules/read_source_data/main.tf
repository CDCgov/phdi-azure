data "archive_file" "read_source_data" {
  type        = "zip"
  source_dir  = "../../../serverless-functions"
  output_path = "function-app.zip"
}

resource "azurerm_storage_account" "function_app_sa" {
  name                     = "phdi${terraform.workspace}functions"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "read_source_data" {
  name                 = "read-source-data"
  storage_account_name = azurerm_storage_account.function_app_sa.name
}

resource "azurerm_storage_blob" "read_source_data_blob" {
  name                   = "${filesha256(data.archive_file.read_source_data.output_path)}.zip"
  storage_account_name   = azurerm_storage_account.function_app_sa.name
  storage_container_name = azurerm_storage_container.read_source_data.name
  type                   = "Block"
  source                 = data.archive_file.read_source_data.output_path
}

data "azurerm_storage_account_blob_container_sas" "storage_account_blob_container_sas" {
  connection_string = azurerm_storage_account.function_app_sa.primary_connection_string
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

resource "azurerm_service_plan" "function_app_sp" {
  name                = "phdi-${terraform.workspace}-azure-functions-sp"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_function_app" "read_source_data" {
  name                       = "phdi-${terraform.workspace}-read-source-data"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  app_service_plan_id        = azurerm_app_service_plan.function_app_sp.id
  storage_account_name       = azurerm_storage_account.function_app_sa.name
  storage_account_access_key = azurerm_storage_account.function_app_sa.primary_access_key
  os_type                    = "linux"
  version                    = "~4"

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "https://${azurerm_storage_account.function_app_sa.name}.blob.core.windows.net/${azurerm_storage_container.read_source_data.name}/${azurerm_storage_blob.read_source_data_blob.name}${data.azurerm_storage_account_blob_container_sas.storage_account_blob_container_sas.sas}"
    FUNCTIONS_WORKER_RUNTIME = "python"
    AzureWebJobsPhiStorage   = var.phi_storage_account_connection_string
    ServiceBusQueueName      = var.ingestion_queue_name
  }

  site_config {
    linux_fx_version = "python|3.9"
  }
}
