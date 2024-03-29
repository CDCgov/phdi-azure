variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the resources."
}

variable "location" {
  type        = string
  description = "The Azure location where the resources should be created."
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

variable "pipeline_runner_id" {
  type        = string
  description = "ID of the pipeline runner identity"
}

variable "pipeline_runner_client_id" {
  type        = string
  description = "Client ID of the pipeline runner identity"
}

variable "client_id" {
  type        = string
  description = "Client ID of the app registration used to authenticate to Azure"
}

variable "wait_time" {
  type        = number
  description = "The number of seconds to wait when polling for a resource."
}

variable "sleep_time" {
  type        = number
  description = "The number of seconds to sleep in lookup tries for a resource."
}

variable "ingestion_container_url" {
  type        = string
  description = "The URL of the ingestion service."
}

variable "record_linkage_container_url" {
  type        = string
  description = "The URL of the record linkage service."
}

variable "phi_storage_account_connection_string" {
  type        = string
  description = "The connection string for the storage account."
}

variable "staging_queue_url" {
  type        = string
  description = "The URL of the staging queue."
}

variable "message_parser_url" {
  type        = string
  description = "URL of the message parser container"
}