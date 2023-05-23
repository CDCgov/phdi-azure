data "azurerm_client_config" "current" {}

data "azuread_application" "github_app" {
  display_name = "github-${var.resource_group_name}"
}