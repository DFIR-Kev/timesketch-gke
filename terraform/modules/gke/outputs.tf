# GKE Module Outputs

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Endpoint for the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_location" {
  description = "Location of the GKE cluster"
  value       = google_container_cluster.primary.location
}

output "cluster_ca_certificate" {
  description = "The cluster CA certificate"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_min_master_version" {
  description = "The minimum master version"
  value       = google_container_cluster.primary.min_master_version
}

output "base_node_pool_name" {
  description = "Name of the base node pool"
  value       = google_container_node_pool.base_nodes.name
}

output "worker_node_pool_name" {
  description = "Name of the worker node pool"
  value       = google_container_node_pool.worker_nodes.name
}