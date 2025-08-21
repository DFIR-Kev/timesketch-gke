# Networking Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "vpc_network" {
  description = "VPC network name"
  type        = string
}

variable "cluster_ipv4_cidr_block" {
  description = "CIDR block for cluster pods"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the GKE master network"
  type        = string
}

variable "billing_labels" {
  description = "Common billing labels for cost attribution"
  type        = map(string)
}