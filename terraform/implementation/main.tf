// Load modules here

module "shared" {
  source              = "../modules/shared"
  resource_group_name = var.resource_group_name
  location            = var.location
}


module "data_factory" {
  source              = "../modules/data_factory"
  resource_group_name = var.resource_group_name
  location            = var.location
}


module "read_source_data" {
  source                                         = "../modules/read_source_data"
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  phi_storage_account_connection_string          = module.shared.phi_storage_account_connection_string
  ingestion_queue_name                           = module.shared.ingestion_queue_name
  service_bus_connection_string                  = module.shared.service_bus_connection_string
  function_app_storage_account_name              = module.shared.function_app_storage_account_name
  function_app_storage_account_access_key        = module.shared.function_app_storage_account_access_key
  function_app_storage_account_connection_string = module.shared.function_app_storage_account_connection_string
  function_app_service_plan_id                   = module.shared.function_app_service_plan_id
  application_insights_instrumentation_key       = module.shared.application_insights_instrumentation_key
}

module "fhir_converter" {
  source                                         = "../modules/fhir_converter"
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  function_app_storage_account_name              = module.shared.function_app_storage_account_name
  function_app_storage_account_access_key        = module.shared.function_app_storage_account_access_key
  function_app_storage_account_connection_string = module.shared.function_app_storage_account_connection_string
  function_app_service_plan_id                   = module.shared.function_app_service_plan_id
  container_registry_url                         = module.shared.container_registry_url
  container_registry_reader_id                   = module.shared.container_registry_reader_id
  application_insights_instrumentation_key       = module.shared.application_insights_instrumentation_key
}
