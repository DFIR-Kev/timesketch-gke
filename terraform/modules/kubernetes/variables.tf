# Kubernetes Module Variables

variable "namespace" {
  description = "Kubernetes namespace for OSDFIR"
  type        = string
}

variable "release_name" {
  description = "Helm release name"
  type        = string
}

variable "filestore_capacity_gb" {
  description = "The capacity of the Filestore instance in GB"
  type        = number
}

variable "filestore_ip_address" {
  description = "IP address of the Filestore instance"
  type        = string
}

variable "timesketch_configs_hash" {
  description = "Hash of the Timesketch configs to trigger updates when configs change"
  type        = string
  default     = "1"  # Default value that can be overridden
}

variable "billing_labels" {
  description = "Common billing labels for cost attribution"
  type        = map(string)
}

# Timesketch is always enabled in this deployment