data "azuread_client_config" "current" {}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_subnet" "kubesubnet" {
  name                 = local.aks_subnet_name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "appgwsubnet" {
  name                 = local.app_gateway_subnet_name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  resource_group_name  = var.resource_group_name
}
