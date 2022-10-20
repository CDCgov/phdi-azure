resource "azurerm_data_factory" "phdi_data_factory" {
  name                            = "${var.resource_prefix}-df"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  public_network_enabled          = false
  managed_virtual_network_enabled = true

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}
