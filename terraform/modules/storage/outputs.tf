output "functions_storage_bucket" {
  value = google_storage_bucket.functions.name
}

output "upcase_source_zip" {
  value = google_storage_bucket_object.upcase_source_zip.name
}

output "upload_fhir_bundle_source_zip" {
  value = google_storage_bucket_object.upload_fhir_bundle_source_zip.name
}

output "read_source_data_source_zip" {
  value = google_storage_bucket_object.read_source_data_source_zip.name
}

output "phi_storage_bucket" {
  value = google_storage_bucket.phi_storage_bucket.name
}

output "add_patient_hash_source_zip" {
  value = google_storage_bucket_object.add_patient_hash_source_zip.name
}

output "toybucket" {
  value = google_storage_bucket.toybucket.name
}

output "standardize_names_zip" {
  value = google_storage_bucket_object.standardize_names_zip.name
}

output "standardize_phones_zip" {
  value = google_storage_bucket_object.standardize_phones_zip.name
}

output "geocode_patients_zip" {
  value = google_storage_bucket_object.geocode_patients_zip.name
}

output "failed_fhir_conversion_zip" {
  value = google_storage_bucket_object.failed_fhir_conversion_zip.name
}

output "failed_fhir_upload_zip" {
  value = google_storage_bucket_object.failed_fhir_upload_zip.name
}
