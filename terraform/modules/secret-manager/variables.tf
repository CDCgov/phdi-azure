variable "project_id" {
  type        = string
  description = "value of the GCP project ID to use"
}

variable "workflow_service_account_email" {
  description = "Service account for workflow"
}

variable "smarty_auth_id" {
  description = "value of google_secret_manager_secret.smarty_auth_id"
}

variable "smarty_auth_token" {
  description = "value of google_secret_manager_secret.smarty_auth_token"
}