// Load modules here

module "shared" {
  source                          = "../modules/shared"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  smarty_auth_id                  = var.smarty_auth_id
  smarty_auth_token               = var.smarty_auth_token
  ingestion_container_identity_id = var.ingestion_container_identity_id
}


module "data_factory" {
  source                           = "../modules/data_factory"
  resource_group_name              = var.resource_group_name
  location                         = var.location
  fhir_converter_url               = var.fhir_converter_url
  ingestion_container_url          = var.ingestion_container_url
  fhir_server_url                  = "https://${module.shared.fhir_server_name}.azurehealthcareapis.com/"
  phi_storage_account_endpoint_url = module.shared.phi_storage_account_endpoint_url
}


module "read_source_data" {
  source                                = "../modules/read_source_data"
  resource_group_name                   = var.resource_group_name
  location                              = var.location
  phi_storage_account_connection_string = module.shared.phi_storage_account_connection_string
  ingestion_queue_name                  = module.shared.ingestion_queue_name
  service_bus_connection_string         = module.shared.service_bus_connection_string
  time_stamp                            = module.shared.time_stamp
}
