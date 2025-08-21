# IAM Module Outputs

output "gke_node_service_account_email" {
  description = "Email of the GKE node service account"
  value       = google_service_account.gke_node_sa.email
}

output "timesketch_service_account_email" {
  description = "Email of the Timesketch GCP service account"
  value       = google_service_account.timesketch_sa.email
}

output "timesketch_service_account_name" {
  description = "Name of the Timesketch GCP service account"
  value       = google_service_account.timesketch_sa.name
}