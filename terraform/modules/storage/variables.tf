# Storage Module Variables

variable "filestore_name" {
  description = "Name of the Filestore instance"
  type        = string
}

variable "filestore_capacity_gb" {
  description = "The capacity of the Filestore instance in GB"
  type        = number
}

variable "zone" {
  description = "The GCP zone"
  type        = string
}

variable "vpc_network" {
  description = "VPC network name"
  type        = string
}

variable "bucket_name" {
  description = "Name of the GCS bucket for Timesketch data"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "billing_labels" {
  description = "Common billing labels for cost attribution"
  type        = map(string)
}