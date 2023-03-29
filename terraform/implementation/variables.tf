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

variable "smarty_licenses" {
  type        = string
  description = "value of the SmartyStreets licenses to use"
}

variable "client_id" {
  description = "Client ID"
}

variable "object_id" {
  description = "Object ID"
}

variable "ghcr_username" {
  type        = string
  description = "GitHub Container Registry username."
}

variable "ghcr_token" {
  type        = string
  description = "GitHub Container Registry token."
}
