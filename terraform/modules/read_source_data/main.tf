resource "azurerm_storage_account" "function_app_sa" {
  name                     = "phdi${terraform.workspace}funcs${substr(var.client_id, 0, 8)}"
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

resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = "workspace-${terraform.workspace}"
  location            = var.location
  resource_group_name = var.resource_group_name
  retention_in_days   = 30
}

resource "azurerm_application_insights" "insights" {
  name                = "phdi-${terraform.workspace}-insights"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log_analytics_workspace.id
}

resource "azurerm_linux_function_app" "read_source_data" {
  name                       = "${terraform.workspace}-read-source-data-${substr(var.client_id, 0, 8)}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  service_plan_id            = azurerm_service_plan.function_app_sp.id
  storage_account_name       = azurerm_storage_account.function_app_sa.name
  storage_account_access_key = azurerm_storage_account.function_app_sa.primary_access_key
  identity {
    type         = "UserAssigned"
    identity_ids = [var.pipeline_runner_id]
  }

  app_settings = {
    WEBSITE_ENABLE_SYNC_UPDATE_SITE    = true
    FUNCTIONS_WORKER_RUNTIME           = "python"
    SCM_DO_BUILD_DURING_DEPLOYMENT     = 1
    RESOURCE_GROUP_NAME                = var.resource_group_name
    FACTORY_NAME                       = var.phdi_data_factory_name
    PIPELINE_NAME                      = var.ingestion_pipeline_name
    AZURE_CLIENT_ID                    = var.pipeline_runner_client_id
    AZURE_TENANT_ID                    = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID              = var.subscription_id
    WAIT_TIME                          = var.wait_time
    SLEEP_TIME                         = var.sleep_time
    INGESTION_URL                      = var.ingestion_container_url
    RECORD_LINKAGE_URL                 = var.record_linkage_container_url
    MESSAGE_PARSER_URL                 = var.message_parser_url
    AzureStorageQueuesConnectionString = var.phi_storage_account_connection_string
    STAGING_QUEUE_URL                  = var.staging_queue_url
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }

  site_config {
    application_stack {
      python_version = "3.9"
    }
    application_insights_key = azurerm_application_insights.insights.instrumentation_key
  }
}
