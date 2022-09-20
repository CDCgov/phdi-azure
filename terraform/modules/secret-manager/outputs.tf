output "patient_hash_salt_secret_id" {
  value = google_secret_manager_secret.salt.secret_id
}

output "patient_hash_salt_secret_version" {
  value = google_secret_manager_secret_version.salt-version.name
}

output "smarty_auth_id_secret_id" {
  value = google_secret_manager_secret.smarty_auth_id.secret_id
}

output "smarty_auth_token_secret_id" {
  value = google_secret_manager_secret.smarty_auth_token.secret_id
}
