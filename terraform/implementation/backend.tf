terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.43.0"
    }
  }

  backend "azurerm" {
    container_name = "tfstate"
    key            = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  use_oidc = var.use_oidc
  features {}
}
