terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.23.0"
    }
  }

  backend "azurerm" {
    use_oidc       = false
    container_name = "tfstate"
    key            = "prod.terraform.tfstate"
    use_msi        = false
  }
}

provider "azurerm" {
  use_oidc = false
  features {}
}
