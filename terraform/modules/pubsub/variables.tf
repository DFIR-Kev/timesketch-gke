# PubSub Module Variables

variable "bucket_name" {
  description = "Name of the GCS bucket to create notifications for"
  type        = string
}

variable "billing_labels" {
  description = "Common billing labels for cost attribution"
  type        = map(string)
}

variable "project_number" {
  description = "The GCP project number"
  type        = string
}