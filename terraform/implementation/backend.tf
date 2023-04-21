terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.43.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 2.37.2"
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

provider "azuread" {
  use_oidc = var.use_oidc
}