variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the resources."
}

variable "location" {
  type        = string
  description = "The Azure location where the resources should be created."
}

variable "phi_storage_account_connection_string" {
  type        = string
  description = "The connection string for the storage account where the PHI data is stored."
}

variable "ingestion_queue_name" {
  type        = string
  description = "The name of the Service Bus queue to which source messages should be posted."
}

variable "service_bus_connection_string" {
  type        = string
  description = "The connection string for the Service Bus namespace."
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
