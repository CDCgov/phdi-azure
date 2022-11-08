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

variable "phdi_data_factory_name" {
  type        = string
  description = "The name of the PHDI ADF resource."
}

variable "ingestion_pipeline_name" {
  type        = string
  description = "The name of the ingestion pipeline in ADF."
}

variable "subscription_id" {
  type        = string
  description = "The Azure subscription ID."
}

variable "time_stamp" {
  type        = string
  description = "The unix timestamp at the time of deployment."
}

variable "pipeline_runner_id" {
  type        = string
  description = "ID of the pipeline runner identity"
}

variable "pipeline_runner_client_id" {
  type        = string
  description = "Client ID of the pipeline runner identity"
}
