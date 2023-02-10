terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.43.0"
    }
  }

  backend "azurerm" {
    use_oidc       = true
    container_name = "tfstate"
    key            = "prod.terraform.tfstate"
    use_msi        = true
  }
}

provider "azurerm" {
  use_oidc = true
  features {}
}
