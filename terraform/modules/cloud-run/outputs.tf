output "fhir_converter_service_name" {
  value = google_cloud_run_service.fhir_converter.name
}

output "fhir_converter_url" {
  value = google_cloud_run_service.fhir_converter.status[0].url
}
