# OSDFIR Applications Module Variables

variable "release_name" {
  description = "Helm release name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for OSDFIR"
  type        = string
}

variable "timesketch_config_map_name" {
  description = "Name of the Timesketch ConfigMap"
  type        = string
}

variable "billing_labels" {
  description = "Common billing labels for cost attribution"
  type        = map(string)
}