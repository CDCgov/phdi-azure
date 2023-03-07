// Load modules here

module "shared" {
  source                     = "../modules/shared"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  smarty_auth_id             = var.smarty_auth_id
  smarty_auth_token          = var.smarty_auth_token
  client_id                  = var.client_id
  object_id                  = var.object_id
  ghcr_username              = var.ghcr_username
  ghcr_token                 = var.ghcr_token
  log_analytics_workspace_id = module.read_source_data.log_analytics_workspace_id
}


module "data_factory" {
  source                  = "../modules/data_factory"
  resource_group_name     = var.resource_group_name
  location                = var.location
  fhir_converter_url      = module.shared.fhir_converter_url
  ingestion_container_url = module.shared.ingestion_container_url
  # tabulation_container_url                = module.shared.tabulation_container_url
  # alerts_container_url                    = module.shared.alerts_container_url
  hapi_container_url                      = module.shared.hapi_container_url
  phi_storage_account_endpoint_url        = module.shared.phi_storage_account_endpoint_url
  pipeline_runner_id                      = module.shared.pipeline_runner_id
  pipeline_runner_principal_id            = module.shared.pipeline_runner_principal_id
  fhir_upload_failures_container_name     = module.shared.fhir_upload_failures_container_name
  fhir_conversion_failures_container_name = module.shared.fhir_conversion_failures_container_name
  client_id                               = var.client_id
}


module "read_source_data" {
  source                     = "../modules/read_source_data"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  phdi_data_factory_name     = module.data_factory.phdi_data_factory_name
  ingestion_pipeline_name    = module.data_factory.ingestion_pipeline_name
  subscription_id            = var.subscription_id
  pipeline_runner_id         = module.shared.pipeline_runner_id
  pipeline_runner_client_id  = module.shared.pipeline_runner_client_id
  client_id                  = var.client_id
  wait_time                  = 10
  sleep_time                 = 1
  subnet_id                  = module.shared.subnet_id
  functionapp_subnet_id      = module.shared.functionapp_subnet_id
  eventhub_name              = module.shared.eventhub_name
  eventhub_connection_string = module.shared.eventhub_connection_string
}
