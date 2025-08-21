# IAM Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "timesketch_gcp_sa" {
  description = "Name of the Timesketch GCP service account"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Timesketch"
  type        = string
}

variable "timesketch_k8s_sa" {
  description = "Name of the Timesketch Kubernetes service account"
  type        = string
}