variable "location" {
  type        = string
  description = "Function App Location"
}

variable "resource_group_name" {
  type        = string
  description = "Resource Group Name"
}

variable "fhir_converter_url" {
  type        = string
  description = "URL of the FHIR conversion service"
}

variable "ingestion_container_url" {
  type        = string
  description = "URL of the ingestion container"
}

variable "message_parser_url" {
  type        = string
  description = "URL of the message parser container"
}

variable "validation_container_url" {
  type        = string
  description = "URL of the validation container"
}

variable "record_linkage_container_url" {
  type        = string
  description = "URL of the record linkage container"
}

variable "fhir_server_url" {
  type        = string
  description = "URL of the FHIR server"
}

variable "phi_storage_account_endpoint_url" {
  type        = string
  description = "URL of the PHI storage account"
}

variable "pipeline_runner_id" {
  type        = string
  description = "ID of the pipeline runner identity"
}

variable "pipeline_runner_principal_id" {
  type        = string
  description = "Principal ID of the pipeline runner identity"
}

variable "pipeline_runner_resource_id" {
  type        = string
  description = "Resource ID of the pipeline runner identity"
}

variable "fhir_upload_failures_container_name" {
  type        = string
  description = "Container name for failed FHIR uploads"
}

variable "delta_tables_container_name" {
  type        = string
  description = "Container name for delta table storage"
}

variable "phi_storage_account_name" {
  type        = string
  description = "PHI storage account name"
}

variable "validation_failures_container_name" {
  type        = string
  description = "Container name for failed validations"
}

variable "fhir_conversion_failures_container_name" {
  type        = string
  description = "Container name for failed FHIR conversions"
}

variable "client_id" {
  type        = string
  description = "Client ID"
}

variable "key_vault_name" {
  type        = string
  description = "Key vault name"
}
