resource "google_artifact_registry_repository" "phdi-repo" {
  location      = var.region
  repository_id = "phdi-${terraform.workspace}-repository"
  description   = "Docker repository"
  format        = "DOCKER"
}
