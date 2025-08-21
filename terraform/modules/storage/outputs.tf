# Storage Module Outputs

output "filestore_instance_name" {
  description = "Name of the Filestore instance"
  value       = google_filestore_instance.osdfir_filestore.name
}

output "filestore_ip_address" {
  description = "IP address of the Filestore instance"
  value       = google_filestore_instance.osdfir_filestore.networks[0].ip_addresses[0]
}

output "filestore_capacity_gb" {
  description = "Capacity of the Filestore instance in GB"
  value       = var.filestore_capacity_gb
}

output "bucket_name" {
  description = "Name of the GCS bucket for Timesketch data"
  value       = google_storage_bucket.timesketch_data.name
}

output "bucket_url" {
  description = "URL of the GCS bucket"
  value       = google_storage_bucket.timesketch_data.url
}