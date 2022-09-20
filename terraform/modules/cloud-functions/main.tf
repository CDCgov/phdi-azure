resource "google_cloudfunctions_function" "upcase" {
  name        = "phdi-${terraform.workspace}-upcase-function"
  description = "Upcase function"
  runtime     = "python39"

  available_memory_mb   = 128
  source_archive_bucket = var.functions_storage_bucket
  source_archive_object = var.upcase_source_zip
  trigger_http          = true
  entry_point           = "upcase_http"
}

resource "google_cloudfunctions_function" "upload-fhir-bundle" {
  name        = "phdi-${terraform.workspace}-upload-fhir-bundle"
  description = "Upload a FHIR bundle to FHIR Store"
  runtime     = "python39"

  available_memory_mb   = 128
  source_archive_bucket = var.functions_storage_bucket
  source_archive_object = var.upload_fhir_bundle_source_zip
  trigger_http          = true
  entry_point           = "upload_fhir_bundle"
}


resource "google_cloudfunctions_function" "read_source_data" {
  name                  = "phdi-${terraform.workspace}-read_source_data"
  description           = "Read source data from bucket and publish to pub/sub topic for ingestion."
  runtime               = "python39"
  available_memory_mb   = 128
  source_archive_bucket = var.functions_storage_bucket
  source_archive_object = var.read_source_data_source_zip
  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = var.phi_storage_bucket
    failure_policy {
      retry = true
    }
  }
  entry_point = "read_source_data"
  environment_variables = {
    PROJECT_ID      = var.project_id
    INGESTION_TOPIC = var.ingestion_topic
  }
}

resource "google_cloudfunctions_function" "add-patient-hash" {
  name                  = "phdi-${terraform.workspace}-add-patient-hash"
  description           = "Add a hash to the patient resource"
  runtime               = "python39"
  available_memory_mb   = 128
  source_archive_bucket = var.functions_storage_bucket
  source_archive_object = var.add_patient_hash_source_zip
  trigger_http          = true
  entry_point           = "add_patient_hash"
  service_account_email = var.workflow_service_account_email

  secret_environment_variables {
    key        = "PATIENT_HASH_SALT"
    secret     = var.patient_hash_salt_secret_id
    version    = "1"
    project_id = var.project_id
  }
}

resource "google_cloudfunctions_function" "standardize-names" {
  name        = "phdi-${terraform.workspace}-standardize-names"
  description = "Standardize names in FHIR Payload"
  runtime     = "python39"

  available_memory_mb   = 128
  source_archive_bucket = var.functions_storage_bucket
  source_archive_object = var.standardize_names_zip
  trigger_http          = true
  entry_point           = "http_standardize_names"
}

resource "google_cloudfunctions_function" "standardize-phones" {
  name        = "phdi-${terraform.workspace}-standardize-phones"
  description = "Standardize phone numbers in FHIR Payload"
  runtime     = "python39"

  available_memory_mb   = 128
  source_archive_bucket = var.functions_storage_bucket
  source_archive_object = var.standardize_phones_zip
  trigger_http          = true
  entry_point           = "http_standardize_phones"
}

resource "google_cloudfunctions_function" "geocode-patients" {
  name                  = "phdi-${terraform.workspace}-geocode-patients"
  description           = "Standardize and Geocode patient addresses"
  runtime               = "python39"
  available_memory_mb   = 128
  source_archive_bucket = var.functions_storage_bucket
  source_archive_object = var.geocode_patients_zip
  trigger_http          = true
  entry_point           = "http_geocode_patients"
  service_account_email = var.workflow_service_account_email

  secret_environment_variables {
    key        = "SMARTY_AUTH_ID"
    secret     = var.smarty_auth_id_secret_id
    version    = "1"
    project_id = var.project_id
  }

  secret_environment_variables {
    key        = "SMARTY_AUTH_TOKEN"
    secret     = var.smarty_auth_token_secret_id
    version    = "1"
    project_id = var.project_id
  }
}

resource "google_cloudfunctions_function" "failed_fhir_conversion" {
  name        = "phdi-${terraform.workspace}-failed-fhir-conversion"
  description = "Upload failed FHIR conversion to GCS"
  runtime     = "python39"

  available_memory_mb   = 128
  source_archive_bucket = var.functions_storage_bucket
  source_archive_object = var.failed_fhir_conversion_zip
  trigger_http          = true
  entry_point           = "failed_fhir_conversion"

  environment_variables = {
    PHI_STORAGE_BUCKET = var.phi_storage_bucket
  }
}

resource "google_cloudfunctions_function" "failed_fhir_upload" {
  name        = "phdi-${terraform.workspace}-failed-fhir-upload"
  description = "Upload failed FHIR upload to GCS"
  runtime     = "python39"

  available_memory_mb   = 128
  source_archive_bucket = var.functions_storage_bucket
  source_archive_object = var.failed_fhir_upload_zip
  trigger_http          = true
  entry_point           = "failed_fhir_upload"

  environment_variables = {
    PHI_STORAGE_BUCKET = var.phi_storage_bucket
  }
}
