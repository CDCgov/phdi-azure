variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the resources."
}

variable "location" {
  type        = string
  description = "The Azure location where the resources should be created."
}

variable "smarty_auth_id" {
  type        = string
  description = "The SmartyStreets Auth ID."
}

variable "smarty_auth_token" {
  type        = string
  description = "The SmartyStreets Auth Token."
}

variable "smarty_license_type" {
  type        = string
  description = "The SmartyStreets license type to use."
}

variable "client_id" {
  type        = string
  description = "Client ID"
}

variable "object_id" {
  type        = string
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

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics Workspace ID."
}

variable "k8s_vnet_address_space" {
  type        = string
  description = "Ip address space for kubernetes vnet"
  default     = "10.30.0.0/16"
}

variable "k8s_subnet_address_prefix" {
  type        = string
  description = "Ip address space for kubernetes subnet vnet"
  default     = "10.30.1.0/24"
}