resource "random_uuid" "salt" {}

resource "google_secret_manager_secret" "salt" {
  secret_id = "PATIENT_HASH_SALT"

  labels = {
    label = "patient-hash-salt"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "salt-version" {
  secret = google_secret_manager_secret.salt.id

  secret_data = random_uuid.salt.result
}

resource "google_secret_manager_secret_iam_member" "workflow-service-account-member" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.salt.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.workflow_service_account_email}"
}

resource "google_secret_manager_secret" "smarty_auth_id" {
  secret_id = "SMARTY_AUTH_ID"

  labels = {
    label = "smarty-auth-id"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "smarty-auth-id-version" {
  secret = google_secret_manager_secret.smarty_auth_id.id

  secret_data = var.smarty_auth_id
}

resource "google_secret_manager_secret_iam_member" "workflow-service-account-member-smarty-id" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.smarty_auth_id.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.workflow_service_account_email}"
}

resource "google_secret_manager_secret" "smarty_auth_token" {
  secret_id = "SMARTY_AUTH_TOKEN"

  labels = {
    label = "smarty-auth-token"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "smarty-auth-token-version" {
  secret = google_secret_manager_secret.smarty_auth_token.id

  secret_data = var.smarty_auth_token
}

resource "google_secret_manager_secret_iam_member" "workflow-service-account-member-smarty-token" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.smarty_auth_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.workflow_service_account_email}"
}
