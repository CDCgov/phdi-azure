// Load modules here

module "shared" {
  source              = "../modules/shared"
  resource_group_name = var.resource_group_name
  location            = var.location
  smarty_auth_id      = var.smarty_auth_id
  smarty_auth_token   = var.smarty_auth_token
  client_id           = var.client_id
}


module "data_factory" {
  source                                  = "../modules/data_factory"
  resource_group_name                     = var.resource_group_name
  location                                = var.location
  fhir_converter_url                      = var.fhir_converter_url
  ingestion_container_url                 = var.ingestion_container_url
  fhir_server_url                         = "https://${module.shared.fhir_server_name}.azurehealthcareapis.com/"
  phi_storage_account_endpoint_url        = module.shared.phi_storage_account_endpoint_url
  pipeline_runner_id                      = module.shared.pipeline_runner_id
  pipeline_runner_principal_id            = module.shared.pipeline_runner_principal_id
  fhir_upload_failures_container_name     = module.shared.fhir_upload_failures_container_name
  fhir_conversion_failures_container_name = module.shared.fhir_conversion_failures_container_name
  client_id                               = var.client_id
}


module "read_source_data" {
  source                                = "../modules/read_source_data"
  resource_group_name                   = var.resource_group_name
  location                              = var.location
  phi_storage_account_connection_string = module.shared.phi_storage_account_connection_string
  phdi_data_factory_name                = module.data_factory.phdi_data_factory_name
  ingestion_pipeline_name               = module.data_factory.ingestion_pipeline_name
  subscription_id                       = var.subscription_id
  time_stamp                            = module.shared.time_stamp
  pipeline_runner_id                    = module.shared.pipeline_runner_id
  pipeline_runner_client_id             = module.shared.pipeline_runner_client_id
  client_id                             = var.client_id
}
