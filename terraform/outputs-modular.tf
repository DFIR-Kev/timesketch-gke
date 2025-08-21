# Outputs for Timesketch GKE Terraform Configuration

# Cluster Information
output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for the GKE cluster"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "cluster_location" {
  description = "Location of the GKE cluster"
  value       = module.gke.cluster_location
}

# kubectl connection command
output "kubectl_connection_command" {
  description = "Command to connect kubectl to the cluster"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --zone ${module.gke.cluster_location} --project ${var.project_id}"
}

# Service Account Information
output "timesketch_gcp_service_account" {
  description = "Email of the Timesketch GCP service account"
  value       = module.iam.timesketch_service_account_email
}

output "gke_node_service_account" {
  description = "Email of the GKE node service account"
  value       = module.iam.gke_node_service_account_email
}

# Storage Information
output "filestore_instance_name" {
  description = "Name of the Filestore instance"
  value       = module.storage.filestore_instance_name
}

output "filestore_ip_address" {
  description = "IP address of the Filestore instance"
  value       = module.storage.filestore_ip_address
}

output "storage_bucket_name" {
  description = "Name of the GCS bucket for Timesketch data"
  value       = module.storage.bucket_name
}

output "storage_bucket_url" {
  description = "URL of the GCS bucket"
  value       = module.storage.bucket_url
}

# No Pub/Sub outputs needed for Timesketch-only deployment

# Networking Information
output "ingress_ip_address" {
  description = "The reserved static IP address for ingress"
  value       = module.networking.ingress_ip_address
}

# Kubernetes Information
output "namespace_name" {
  description = "Name of the OSDFIR namespace"
  value       = module.kubernetes.namespace_name
}

output "shared_pvc_name" {
  description = "Name of the shared PVC"
  value       = module.kubernetes.pvc_name
}

# Application Information
output "helm_release_name" {
  description = "Name of the Timesketch Helm release"
  value       = module.osdfir_apps.helm_release_name
}

# Basic project information
output "project_id" { 
  value = var.project_id 
}

output "region" { 
  value = var.region 
}

# Deployment Complete Message
output "deployment_complete" {
  description = "Deployment complete message"
  value = <<-EOT
    
    🎉 Timesketch on GKE deployed successfully!
    
    📋 What was deployed:
    - GKE cluster: ${module.gke.cluster_name}
    - Filestore instance: ${module.storage.filestore_instance_name}
    - Storage bucket: ${module.storage.bucket_name}
    - Timesketch application
    
    📋 Next Steps:
    1. Connect to your cluster:
       ${local.kubectl_command}
    
    2. Setup port forwarding:
        scripts\manage-osdfir-gke.ps1 start
    3. Check status of deployment:
        scripts\manage-osdfir-gke.ps1 status
    4. Get Timesketch login credentials:
        scripts\manage-osdfir-gke.ps1 creds -Service timesketch
  EOT
}

# Local values for computed strings
locals {
  kubectl_command = "gcloud container clusters get-credentials ${module.gke.cluster_name} --zone ${module.gke.cluster_location} --project ${var.project_id}"
}