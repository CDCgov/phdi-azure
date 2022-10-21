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