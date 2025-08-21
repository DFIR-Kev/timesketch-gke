# Terraform Variables for OSDFIR Infrastructure
# Copy this file to terraform.tfvars and customize for your environment
# Configuration matches the bash script osdfir-init-gke.sh defaults

# Project Configuration
project_id     = "d96282"
project_number = "510111674200"
region         = "us-central1"
zone          = "us-central1-f"

# Environment
environment = "production"

# Cluster Configuration (matching bash script)
cluster_name = "osdfir-infra"

# Node Configuration (cost-optimized for OSDFIR workloads)
node_count       = 1
min_node_count   = 1
max_node_count   = 20
machine_type     = "e2-standard-16"  # 16 vCPUs, 64GB RAM
disk_size_gb     = 200
preemptible_nodes = false

# Storage Configuration
filestore_name        = "osdfir-filestore-rwx"
filestore_capacity_gb = 1024  # 1TB as per bash script
bucket_name          = "timesketch-data-bucket"
pvc_size            = "1Ti"

# Network Configuration (matching bash script defaults)
vpc_network              = "default"
vpc_subnetwork           = ""
master_ipv4_cidr_block   = "172.16.0.0/28"
cluster_ipv4_cidr_block  = "10.1.0.0/16"
services_ipv4_cidr_block = "10.2.0.0/16"

# Service Account Names
timesketch_gcp_sa = "timesketch-gsa"
timesketch_k8s_sa = "timesketch-k8s-sa"

# Kubernetes Configuration (matching bash script)
namespace    = "osdfir"
release_name = "osdfir"

# Helm Chart Version (leave empty for latest)
helm_chart_version = "" 