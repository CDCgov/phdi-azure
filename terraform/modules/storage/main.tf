resource "google_storage_bucket" "toybucket" {
  name          = "phdi-${terraform.workspace}-toybucket-${var.project_id}"
  location      = "US"
  force_destroy = true
  versioning {
    enabled = true
  }
  storage_class = "MULTI_REGIONAL"
}

resource "google_storage_bucket" "phi_storage_bucket" {
  name          = "phdi-${terraform.workspace}-phi-bucket-${var.project_id}"
  location      = "US"
  force_destroy = true
  versioning {
    enabled = true
  }
  storage_class = "MULTI_REGIONAL"
}

resource "google_storage_bucket" "functions" {
  name          = "phdi-${terraform.workspace}-functions-${var.project_id}"
  location      = "US"
  force_destroy = true
  versioning {
    enabled = true
  }
  storage_class = "MULTI_REGIONAL"
}

data "archive_file" "upcase_source" {
  type        = "zip"
  source_dir  = "../../cloud-functions/upcase_http"
  output_path = "../../cloud-functions/upcase_function.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "upcase_source_zip" {
  source       = data.archive_file.upcase_source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${terraform.workspace}-${data.archive_file.upcase_source.output_md5}.zip"
  bucket = google_storage_bucket.functions.name
}

data "archive_file" "upload_fhir_bundle" {
  type        = "zip"
  source_dir  = "../../cloud-functions/upload_fhir_bundle"
  output_path = "../../cloud-functions/upload_fhir_bundle.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "upload_fhir_bundle_source_zip" {
  source       = data.archive_file.upload_fhir_bundle.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${terraform.workspace}-${data.archive_file.upload_fhir_bundle.output_md5}.zip"
  bucket = google_storage_bucket.functions.name
}

data "archive_file" "read_source_data" {
  type        = "zip"
  source_dir  = "../../cloud-functions/read_source_data"
  output_path = "../../cloud-functions/read_source_data.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "read_source_data_source_zip" {
  source       = data.archive_file.read_source_data.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${terraform.workspace}-${data.archive_file.read_source_data.output_md5}.zip"
  bucket = google_storage_bucket.functions.name
}

data "archive_file" "standardize_names" {
  type        = "zip"
  source_dir  = "../../cloud-functions/http_standardize_names"
  output_path = "../../cloud-functions/standardize_names.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "standardize_names_zip" {
  source       = data.archive_file.standardize_names.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.standardize_names.output_md5}-${var.project_id}.zip"
  bucket = google_storage_bucket.functions.name
}

data "archive_file" "add_patient_hash" {
  type        = "zip"
  source_dir  = "../../cloud-functions/add_patient_hash"
  output_path = "../../cloud-functions/add_patient_hash.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "add_patient_hash_source_zip" {
  source       = data.archive_file.add_patient_hash.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${terraform.workspace}-${data.archive_file.add_patient_hash.output_md5}.zip"
  bucket = google_storage_bucket.functions.name
}

data "archive_file" "standardize_phones" {
  type        = "zip"
  source_dir  = "../../cloud-functions/http_standardize_phones"
  output_path = "../../cloud-functions/standardize_phones.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "standardize_phones_zip" {
  source       = data.archive_file.standardize_phones.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.standardize_phones.output_md5}-${var.project_id}.zip"
  bucket = google_storage_bucket.functions.name
}

data "archive_file" "geocode_patients" {
  type        = "zip"
  source_dir  = "../../cloud-functions/http_geocode_patients"
  output_path = "../../cloud-functions/geocode_patients.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "geocode_patients_zip" {
  source       = data.archive_file.geocode_patients.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.geocode_patients.output_md5}-${var.project_id}.zip"
  bucket = google_storage_bucket.functions.name
}

data "archive_file" "failed_fhir_conversion" {
  type        = "zip"
  source_dir  = "../../cloud-functions/failed_fhir_conversion"
  output_path = "../../cloud-functions/failed_fhir_conversion.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "failed_fhir_conversion_zip" {
  source       = data.archive_file.failed_fhir_conversion.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.failed_fhir_conversion.output_md5}-${var.project_id}.zip"
  bucket = google_storage_bucket.functions.name
}

data "archive_file" "failed_fhir_upload" {
  type        = "zip"
  source_dir  = "../../cloud-functions/failed_fhir_upload"
  output_path = "../../cloud-functions/failed_fhir_upload.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "failed_fhir_upload_zip" {
  source       = data.archive_file.failed_fhir_upload.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.failed_fhir_upload.output_md5}-${var.project_id}.zip"
  bucket = google_storage_bucket.functions.name
}
