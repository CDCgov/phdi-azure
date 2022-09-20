output "upload_fhir_bundle_url" {
  value = google_cloudfunctions_function.upload-fhir-bundle.https_trigger_url
}

output "read_source_data_url" {
  value = google_cloudfunctions_function.read_source_data.https_trigger_url
}

output "add_patient_hash_url" {
  value = google_cloudfunctions_function.add-patient-hash.https_trigger_url
}

output "standardize_phones_url" {
  value = google_cloudfunctions_function.standardize-phones.https_trigger_url
}

output "standardize_names_url" {
  value = google_cloudfunctions_function.standardize-names.https_trigger_url
}

output "failed_fhir_conversion_url" {
  value = google_cloudfunctions_function.failed_fhir_conversion.https_trigger_url
}

output "failed_fhir_upload_url" {
  value = google_cloudfunctions_function.failed_fhir_upload.https_trigger_url
}

output "geocode_patients_url" {
  value = google_cloudfunctions_function.geocode-patients.https_trigger_url
}

