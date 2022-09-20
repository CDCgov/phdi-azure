provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_project_service" "enable_google_apis" {
  for_each = toset(var.gcp_services_list)
  project  = var.project_id
  service  = each.key

  disable_on_destroy = false
}


module "storage" {
  source     = "../modules/storage"
  project_id = var.project_id
  depends_on = [google_project_service.enable_google_apis]
}

module "cloud-functions" {
  source                           = "../modules/cloud-functions"
  project_id                       = var.project_id
  functions_storage_bucket         = module.storage.functions_storage_bucket
  phi_storage_bucket               = module.storage.phi_storage_bucket
  upcase_source_zip                = module.storage.upcase_source_zip
  upload_fhir_bundle_source_zip    = module.storage.upload_fhir_bundle_source_zip
  read_source_data_source_zip      = module.storage.read_source_data_source_zip
  ingestion_topic                  = module.pubsub.ingestion_topic
  add_patient_hash_source_zip      = module.storage.add_patient_hash_source_zip
  patient_hash_salt_secret_id      = module.secret-manager.patient_hash_salt_secret_id
  patient_hash_salt_secret_version = module.secret-manager.patient_hash_salt_secret_version
  smarty_auth_id_secret_id         = module.secret-manager.smarty_auth_id_secret_id
  smarty_auth_token_secret_id      = module.secret-manager.smarty_auth_token_secret_id
  standardize_phones_zip           = module.storage.standardize_phones_zip
  standardize_names_zip            = module.storage.standardize_names_zip
  failed_fhir_conversion_zip       = module.storage.failed_fhir_conversion_zip
  failed_fhir_upload_zip           = module.storage.failed_fhir_upload_zip
  geocode_patients_zip             = module.storage.geocode_patients_zip
  workflow_service_account_email   = module.google-workflows.workflow_service_account_email
  depends_on                       = [google_project_service.enable_google_apis]
}

module "google-workflows" {
  source                      = "../modules/google-workflows"
  region                      = var.region
  project_id                  = var.project_id
  fhir_converter_service_name = module.cloud-run.fhir_converter_service_name
  fhir_converter_url          = module.cloud-run.fhir_converter_url
  upload_fhir_bundle_url      = module.cloud-functions.upload_fhir_bundle_url
  read_source_data_url        = module.cloud-functions.read_source_data_url
  add_patient_hash_url        = module.cloud-functions.add_patient_hash_url
  standardize_phones_url      = module.cloud-functions.standardize_phones_url
  standardize_names_url       = module.cloud-functions.standardize_names_url
  failed_fhir_conversion_url  = module.cloud-functions.failed_fhir_conversion_url
  failed_fhir_upload_url      = module.cloud-functions.failed_fhir_upload_url
  geocode_patients_url        = module.cloud-functions.geocode_patients_url
  ingestion_topic             = module.pubsub.ingestion_topic
  depends_on                  = [google_project_service.enable_google_apis]
}

module "network" {
  source     = "../modules/network"
  region     = var.region
  depends_on = [google_project_service.enable_google_apis]
}

module "fhir" {
  source       = "../modules/fhir"
  region       = var.region
  time_zone    = "UTC"
  fhir_version = "R4"
  project_id   = var.project_id
  depends_on   = [google_project_service.enable_google_apis]
}

module "artifact-registries" {
  source     = "../modules/artifact-registries"
  region     = var.region
  depends_on = [google_project_service.enable_google_apis]
}

module "cloud-run" {
  source                         = "../modules/cloud-run"
  region                         = var.region
  project_id                     = var.project_id
  workflow_service_account_email = module.google-workflows.workflow_service_account_email
  git_sha                        = data.external.git_sha.result.sha
  depends_on = [
    google_project_service.enable_google_apis,
    module.artifact-registries.phdi-repo
  ]
}

module "pubsub" {
  source                         = "../modules/pubsub"
  project_id                     = var.project_id
  workflow_service_account_email = module.google-workflows.workflow_service_account_email
  depends_on                     = [google_project_service.enable_google_apis]
}

module "secret-manager" {
  source                         = "../modules/secret-manager"
  project_id                     = var.project_id
  workflow_service_account_email = module.google-workflows.workflow_service_account_email
  depends_on                     = [google_project_service.enable_google_apis]
  smarty_auth_id                 = var.smarty_auth_id
  smarty_auth_token              = var.smarty_auth_token
}
