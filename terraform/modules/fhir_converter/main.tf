resource "azurerm_linux_function_app" "fhir_converter" {
  name                       = "phdi-${terraform.workspace}-fhir-converter"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  service_plan_id            = var.function_app_service_plan_id
  storage_account_name       = var.function_app_storage_account_name
  storage_account_access_key = var.function_app_storage_account_access_key

  app_settings = {

  }

  site_config {
    application_stack {
      docker {
        registry_url = var.container_registry_url
        image_name   = "phdi/fhir-converter"
        image_tag    = "latest"
      }
    }

    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = var.container_registry_reader_id
  }
}
