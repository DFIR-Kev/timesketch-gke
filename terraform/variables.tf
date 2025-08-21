# Variables for OSDFIR Infrastructure Terraform Configuration

# Project Configuration
variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "d96282"
}

variable "project_number" {
  description = "The GCP project number"
  type        = string
  default     = "510111674200"
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-central1-f"
}

# Environment Configuration
variable "environment" {
  description = "Environment (development or production)"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["development", "production"], var.environment)
    error_message = "Environment must be either 'development' or 'production'."
  }
}

# Billing and Cost Attribution Configuration
variable "billing_code" {
  description = "Billing code for cost attribution and reporting"
  type        = string
  default     = "osdfir-test-env"
}

variable "cost_center" {
  description = "Cost center for budget allocation"
  type        = string
  default     = "dfir-platform"
}

variable "owner" {
  description = "Owner/team responsible for this infrastructure"
  type        = string
  default     = "dfir-team"
}

# Cluster Configuration
variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "osdfir-cluster"
}

# Base Node Pool Configuration (always-on for core services)
variable "base_node_count" {
  description = "Number of nodes in the base node pool (always-on)"
  type        = number
  default     = 1
}

variable "base_machine_type" {
  description = "Machine type for base GKE nodes (core services)"
  type        = string
  default     = "e2-standard-16"  # Changed from e2-standard-4 to handle core service load
}

# Worker Node Pool Configuration (autoscaling for compute workloads)
variable "worker_min_node_count" {
  description = "Minimum number of nodes in the worker node pool"
  type        = number
  default     = 0  # Start with 0, scale up as needed
}

variable "worker_max_node_count" {
  description = "Maximum number of nodes in the worker node pool"
  type        = number
  default     = 10  # Limit for cost control
}

variable "worker_machine_type" {
  description = "Machine type for worker GKE nodes (compute-intensive workloads)"
  type        = string
  default     = "e2-standard-16"  # Larger for Plaso, analysis workloads
}

variable "worker_disk_size_gb" {
  description = "Disk size in GB for worker GKE nodes"
  type        = number
  default     = 200
}

# Legacy variables for backward compatibility (deprecated)
variable "node_count" {
  description = "DEPRECATED: Use base_node_count instead"
  type        = number
  default     = 1
}

variable "min_node_count" {
  description = "DEPRECATED: Use worker_min_node_count instead"
  type        = number
  default     = 0
}

variable "max_node_count" {
  description = "DEPRECATED: Use worker_max_node_count instead"
  type        = number
  default     = 10
}

variable "machine_type" {
  description = "DEPRECATED: Use base_machine_type instead"
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Disk size in GB for GKE nodes (matching bash script)"
  type        = number
  default     = 1024
}

variable "preemptible_nodes" {
  description = "Use preemptible nodes for cost savings (worker pool only)"
  type        = bool
  default     = true  # Enable for worker nodes to save costs
}

# Network Configuration (matching bash script)
variable "vpc_network" {
  description = "VPC network name"
  type        = string
  default     = "default"
}

variable "vpc_subnetwork" {
  description = "VPC subnetwork name"
  type        = string
  default     = ""
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the master network"
  type        = string
  default     = "172.16.0.0/28"
}

variable "cluster_ipv4_cidr_block" {
  description = "CIDR block for cluster pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_ipv4_cidr_block" {
  description = "CIDR block for cluster services"
  type        = string
  default     = "10.2.0.0/16"
}

# Storage Configuration
variable "filestore_name" {
  description = "Name of the Filestore instance"
  type        = string
  default     = "osdfir-filestore-rwx"
}

variable "filestore_capacity_gb" {
  type        = number
  description = "The capacity of the Filestore instance in GB."
  default     = 2048 # Changed from 1024 to 2048 to match the new 2TB size
}

variable "bucket_name" {
  description = "Name of the GCS bucket for Timesketch data"
  type        = string
  default     = "timesketch-data-bucket"
}

variable "pvc_size" {
  description = "Size of the PersistentVolumeClaim"
  type        = string
  default     = "2Ti"
}

# Kubernetes Configuration
variable "namespace" {
  description = "Kubernetes namespace for OSDFIR"
  type        = string
  default     = "osdfir"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "osdfir-fci"
}

variable "helm_chart_version" {
  description = "Version of the OSDFIR Helm chart"
  type        = string
  default     = ""  # Use latest if empty
}

# Service Account Configuration
variable "timesketch_gcp_sa" {
  description = "Name of the Timesketch GCP service account"
  type        = string
  default     = "timesketch-gsa"
}

variable "timesketch_k8s_sa" {
  description = "Name of the Timesketch Kubernetes service account"
  type        = string
  default     = "timesketch-k8s-sa"
}

variable "timesketch_configs_hash" {
  description = "Hash of the Timesketch configs to trigger updates when configs change"
  type        = string
  default     = "1"  # Default value that can be overridden
} 