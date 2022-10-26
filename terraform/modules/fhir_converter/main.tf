resource "azurerm_service_plan" "fhir_converter" {
  name                = "phdi-${terraform.workspace}-fhir-converter"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "S1"
}


resource "azurerm_linux_web_app" "fhir_converter" {
  name                = "phdi-${terraform.workspace}-fhir-converter"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.fhir_converter.id

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }

  site_config {
    application_stack {
      docker_image = "ghcr.io/cdcgov/phdi/fhir-converter"
    }
  }
}
