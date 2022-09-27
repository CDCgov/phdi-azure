terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.23.0"
    }
  }

  backend "azurerm" {
    container_name = "tfstate"
    key            = "prod.terraform.tfstate"
    use_msi        = true
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
