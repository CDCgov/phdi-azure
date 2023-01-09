variable "subscription_id" {
  description = "value of the Azure Subscription ID to use"
}

variable "location" {
  description = "value of the Azure location to deploy to"
  default     = "Central US"
}

variable "resource_group_name" {
  description = "value of the Azure resource group to deploy to"
}

variable "smarty_auth_id" {
  description = "value of the SmartyStreets Auth ID"
}

variable "smarty_auth_token" {
  description = "value of the SmartyStreets Auth Token"
}

variable "fhir_converter_url" {
  description = "URL of the FHIR converter"
}

variable "ingestion_container_url" {
  description = "URL of the ingestion container"
}

variable "client_id" {
  description = "Client ID"
}

variable "alerts_container_url" {
  description = "URL of the alerts container"
}

variable "alerts_config" {
  description = "Configuration for alerts"
  type = object({
    sms = object({
      enabled     = bool
      destination = string
    })
    slack = object({
      enabled     = bool
      destination = string
    })
    teams = object({
      enabled     = bool
      destination = string
    })
  })
}
