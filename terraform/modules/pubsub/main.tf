resource "google_pubsub_topic" "ingestion_topic" {
  name                       = "phdi-${terraform.workspace}-ingestion-topic"
  message_retention_duration = "86400s"
}

resource "google_pubsub_topic_iam_member" "ingestion_topic_member" {
  project = var.project_id
  topic   = google_pubsub_topic.ingestion_topic.name
  role    = "roles/editor"
  member  = "serviceAccount:${var.workflow_service_account_email}"
}
