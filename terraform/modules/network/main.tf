resource "google_compute_network" "phdi-network" {
  name                    = "phdi-${terraform.workspace}-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "phdi-subnet" {
  name          = "phdi-${terraform.workspace}-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.phdi-network.id
  secondary_ip_range {
    range_name    = "phdi-${terraform.workspace}-subnet-secondary-range-update1"
    ip_cidr_range = "192.168.10.0/24"
  }
}
