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

variable "fhir_upload_failures_container_name" {
  type        = string
  description = "Container name for failed FHIR uploads"
}

variable "fhir_conversion_failures_container_name" {
  type        = string
  description = "Container name for failed FHIR conversions"
}
