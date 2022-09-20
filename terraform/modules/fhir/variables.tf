variable "time_zone" {
  type        = string
  description = "The default timezone used by this dataset. Must be a either a valid IANA time zone name or empty, which defaults to UTC."
  default     = "UTC"
}

variable "fhir_version" {
  type        = string
  description = "The FHIR specification version. Default value is STU3. Possible values are DSTU2, STU3, and R4."
  default     = "R4"
}

variable "region" {
  type        = string
  description = "The GCP region to deploy to"
  default     = "us-east1"
}

variable "project_id" {
  description = "value of the GCP project ID to use"
}
