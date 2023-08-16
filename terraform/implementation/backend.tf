terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.69.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 2.41.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "= 1.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.5.1"
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

provider "azapi" {
  use_oidc = var.use_oidc
}
