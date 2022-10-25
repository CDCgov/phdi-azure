// Load modules here

module "shared" {
  source              = "../modules/shared"
  resource_group_name = var.resource_group_name
  location            = var.location
}

module "read_source_data" {
  source                                = "../modules/read_source_data"
  resource_group_name                   = var.resource_group_name
  location                              = var.location
  phi_storage_account_connection_string = module.shared.phi_storage_account_connection_string
  ingestion_queue_name                  = module.shared.ingestion_queue_name
  service_bus_connection_string         = module.shared.service_bus_connection_string
}
