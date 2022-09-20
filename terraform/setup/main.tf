###########################################################################################
#
# This file creates the bare minimum infrastructure to start storing remote state.
# It can't store its own remote state, so this file contains only one resource.
#
# In other words, do not apply this file multiple times, as it will fail due to lack of
# state - it won't know it already created the resources.
#
###########################################################################################

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_storage_bucket" "tfstate" {
  name          = "phdi-tfstate-${var.project_id}"
  force_destroy = true
  location      = "US"
  storage_class = "MULTI_REGIONAL"
}
