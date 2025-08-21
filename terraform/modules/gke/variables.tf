# GKE Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "zone" {
  description = "The GCP zone"
  type        = string
}

variable "vpc_network" {
  description = "VPC network name"
  type        = string
}

variable "vpc_subnetwork" {
  description = "VPC subnetwork name"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the master network"
  type        = string
}

variable "cluster_ipv4_cidr_block" {
  description = "CIDR block for cluster pods"
  type        = string
}

variable "services_ipv4_cidr_block" {
  description = "CIDR block for cluster services"
  type        = string
}

variable "base_node_count" {
  description = "Number of nodes in the base node pool (always-on)"
  type        = number
}

variable "base_machine_type" {
  description = "Machine type for base GKE nodes (core services)"
  type        = string
}

variable "worker_min_node_count" {
  description = "Minimum number of nodes in the worker node pool"
  type        = number
}

variable "worker_max_node_count" {
  description = "Maximum number of nodes in the worker node pool"
  type        = number
}

variable "worker_machine_type" {
  description = "Machine type for worker GKE nodes (compute-intensive workloads)"
  type        = string
}

variable "worker_disk_size_gb" {
  description = "Disk size in GB for worker GKE nodes"
  type        = number
}

variable "disk_size_gb" {
  description = "Disk size in GB for base GKE nodes"
  type        = number
}

variable "preemptible_nodes" {
  description = "Use preemptible nodes for cost savings (worker pool only)"
  type        = bool
}

variable "node_service_account_email" {
  description = "Email of the service account for GKE nodes"
  type        = string
}

variable "billing_labels" {
  description = "Common billing labels for cost attribution"
  type        = map(string)
}

variable "required_apis" {
  description = "Dependencies on required Google APIs"
  type        = list(any)
}