module "shared" {
  source              = "../modules/shared"
  resource_group_name = var.resource_group_name
  location            = var.location
}
