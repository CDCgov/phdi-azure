variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the resources."
}

variable "location" {
  type        = string
  description = "The Azure location where the resources should be created."
}

variable "function_app_storage_account_name" {
  type        = string
  description = "The name of the storage account to use for the Function App."
}

variable "function_app_storage_account_access_key" {
  type        = string
  description = "The access key for the storage account to use for the Function App."
}

variable "function_app_storage_account_connection_string" {
  type        = string
  description = "The connection string for the storage account to use for the Function App."
}

variable "function_app_service_plan_id" {
  type        = string
  description = "The ID of the App Service Plan to use for the Function App."
}

variable "container_registry_url" {
  type        = string
  description = "The URL of the container registry to use for the Function App."
}

variable "container_registry_reader_id" {
  type        = string
  description = "The ID of the reader role for the container registry to use for the Function App."
}
