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
