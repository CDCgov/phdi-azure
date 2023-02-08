terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.23.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.1"
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

provider "docker" {
  host = "unix:///var/run/docker.sock"
}
