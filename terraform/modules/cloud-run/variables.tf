variable "region" {
  type        = string
  description = "The GCP region to deploy to"
}

variable "project_id" {
  type        = string
  description = "value of the GCP project ID to use"
}

variable "workflow_service_account_email" {
  description = "Service account for workflow"
}

variable "git_sha" {
  description = "Git SHA of the current commit"
}
