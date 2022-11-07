resource "azurerm_storage_account" "function_app_sa" {
  name                     = "phdi${terraform.workspace}funcs${substr(var.time_stamp, 0, 10)}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "read_source_data" {
  name                 = "read-source-data"
  storage_account_name = azurerm_storage_account.function_app_sa.name
}

resource "azurerm_service_plan" "function_app_sp" {
  name                = "phdi-${terraform.workspace}-azure-functions-sp"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_application_insights" "insights" {
  name                = "phdi-${terraform.workspace}-insights"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
}

resource "azurerm_linux_function_app" "read_source_data" {
  name                       = "phdi-${terraform.workspace}-read-source-data"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  service_plan_id            = azurerm_service_plan.function_app_sp.id
  storage_account_name       = azurerm_storage_account.function_app_sa.name
  storage_account_access_key = azurerm_storage_account.function_app_sa.primary_access_key
  identity {
    type = "UserAssigned"
    identity_ids = [var.pipeline_runner_id]
  }

  app_settings = {
    WEBSITE_ENABLE_SYNC_UPDATE_SITE = true
    FUNCTIONS_WORKER_RUNTIME        = "python"
    SCM_DO_BUILD_DURING_DEPLOYMENT  = 1
    AzureWebJobsPhiStorage          = var.phi_storage_account_connection_string
    AzureServiceBusConnectionString = var.service_bus_connection_string
    ServiceBusQueueName             = var.ingestion_queue_name
    SUBSCRIPTION_ID                 = var.subscription_id
    RESOURCE_GROUP_NAME             = var.resource_group_name
    FACTORY_NAME                    = var.phdi_data_factory_name
    PIPELINE_NAME                   = var.ingestion_pipeline_name
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"]
    ]
  }

  site_config {
    application_stack {
      python_version = "3.9"
    }
    application_insights_key = azurerm_application_insights.insights.instrumentation_key
  }
}
