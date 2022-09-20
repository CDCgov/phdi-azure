resource "google_healthcare_dataset" "dataset" {
  name      = "phdi-${terraform.workspace}-dataset-${var.project_id}"
  location  = var.region
  time_zone = var.time_zone
}

resource "google_healthcare_fhir_store" "default" {
  name    = "phdi-${terraform.workspace}-fhirstore"
  dataset = google_healthcare_dataset.dataset.id
  version = var.fhir_version

  enable_update_create          = false
  disable_referential_integrity = false
  disable_resource_versioning   = false
  enable_history_import         = false

}
