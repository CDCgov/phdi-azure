data "azurerm_client_config" "current" {}

data "http" "runner_ip" {
  url = "https://api.ipify.org"
}