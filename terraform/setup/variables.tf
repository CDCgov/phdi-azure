variable "project_id" {
  description = "value of the GCP project ID to use"
}

variable "region" {
  description = "value of the GCP region to deploy to"
  default     = "us-east1"
}

variable "zone" {
  description = "value of the GCP zone to deploy to"
  default     = "us-east1-b"
}
