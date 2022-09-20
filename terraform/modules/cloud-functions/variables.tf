variable "project_id" {
  description = "value of the GCP project ID to use"
}

variable "functions_storage_bucket" {
  description = "value of google_storage_bucket.functions.name"
}

variable "phi_storage_bucket" {
  description = "value of google_pubsub_topic.ingestion_topic.name"
}

variable "ingestion_topic" {
  description = "value of google_storage_bucket.phi.name"
}

variable "upcase_source_zip" {
  description = "value of google_storage_bucket_object.upcase_source_zip.name"
}

variable "upload_fhir_bundle_source_zip" {
  description = "value of google_storage_bucket_object.upload_fhir_bundle_source_zip.name"
}

variable "read_source_data_source_zip" {
  description = "value of google_storage_bucket_object.read_source_data_source_zip.name"
}

variable "standardize_names_zip" {
  description = "value of google_storage_bucket_object.standardize_names_source_zip.name"
}

variable "standardize_phones_zip" {
  description = "value of google_storage_bucket_object.standardize_phones_source_zip.name"
}

variable "add_patient_hash_source_zip" {
  description = "value of google_storage_bucket_object.add_patient_hash_source_zip.name"
}

variable "failed_fhir_conversion_zip" {
  description = "value of google_storage_bucket_object.failed_fhir_conversion_zip.name"
}

variable "failed_fhir_upload_zip" {
  description = "value of google_storage_bucket_object.failed_fhir_upload_zip.name"
}

variable "patient_hash_salt_secret_id" {
  description = "value of google_secret_manager_secret.salt.id"
}

variable "patient_hash_salt_secret_version" {
  description = "value of google_secret_manager_secret_version.salt-version.name"
}

variable "workflow_service_account_email" {
  description = "value of google_service_account.workflow_service_account.email"
}

variable "geocode_patients_zip" {
  description = "value of google_storage_bucket_object.geocode_patients_source_zip.name"
}

variable "smarty_auth_id_secret_id" {
  description = "value of google_secret_manager_secret.smarty_auth_id"
}

variable "smarty_auth_token_secret_id" {
  description = "value of google_secret_manager_secret.smarty_auth_token"
}
