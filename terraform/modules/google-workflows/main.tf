resource "google_service_account" "workflow_service_account" {
  account_id   = "phdi-${terraform.workspace}-workflow-sa"
  display_name = "Service Account for Google Workflows"
}

resource "google_workflows_workflow" "ingestion-pipeline" {
  name            = "phdi-${terraform.workspace}-ingestion-pipeline"
  region          = var.region
  description     = "A workflow to orchestrate the PHDI pipeline"
  service_account = google_service_account.workflow_service_account.id
  source_contents = templatefile("../../google-workflows/ingestion-pipeline.yaml", {
    fhir_converter_url         = var.fhir_converter_url,
    upload_fhir_bundle_url     = var.upload_fhir_bundle_url,
    read_source_data_url       = var.read_source_data_url,
    add_patient_hash_url       = var.add_patient_hash_url,
    standardize_phones_url     = var.standardize_phones_url,
    standardize_names_url      = var.standardize_names_url,
    failed_fhir_conversion_url = var.failed_fhir_conversion_url,
    failed_fhir_upload_url     = var.failed_fhir_upload_url,
    geocode_patients_url       = var.geocode_patients_url
  })
}

resource "google_eventarc_trigger" "new-message" {
  name     = "phdi-${terraform.workspace}-new-message"
  location = var.region
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }
  transport {
    pubsub {
      topic = var.ingestion_topic
    }
  }
  destination {
    workflow = google_workflows_workflow.ingestion-pipeline.id
  }
  service_account = google_service_account.workflow_service_account.id
}

resource "google_project_iam_member" "workflow_invoker" {
  project = var.project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.workflow_service_account.email}"
}

resource "google_project_iam_member" "function_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.workflow_service_account.email}"
}

resource "google_project_iam_member" "event_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.workflow_service_account.email}"
}

resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workflow_service_account.email}"
}
