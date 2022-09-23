variable "subscription_id" {
  description = "value of the Azure Subscription ID to use"
}

variable "location" {
  description = "value of the Azure location to deploy to"
  default     = "Central US"
}

variable "zone" {
  description = "value of the Azure zone to deploy to"
  default     = "Zone 1"
}
