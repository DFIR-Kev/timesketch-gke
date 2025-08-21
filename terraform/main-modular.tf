# Timesketch GKE Deployment via Terraform
# This file manages the deployment of Timesketch on Google Kubernetes Engine

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Get current Google Cloud client configuration
data "google_client_config" "default" {}

# Enable required Google APIs
locals {
  required_services = [
    "serviceusage.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "file.googleapis.com",
    "storage.googleapis.com",
    "artifactregistry.googleapis.com",
    "containerregistry.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iamcredentials.googleapis.com",
  ]
  
  # Common billing labels for cost attribution
  billing_labels = {
    billing-code    = var.billing_code
    environment     = var.environment
    project         = "timesketch"
    component       = "infrastructure"
    cost-center     = var.cost_center
    owner           = var.owner
  }

  # Hash of Timesketch configs for triggering updates
  timesketch_configs_hash = sha256(join("", [for f in fileset("${path.root}/../configs/data", "**") : filesha256("${path.root}/../configs/data/${f}")]))
}

resource "google_project_service" "required" {
  for_each           = toset(local.required_services)
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# IAM Module - Service accounts and permissions
module "iam" {
  source = "./modules/iam"

  project_id         = var.project_id
  cluster_name       = var.cluster_name
  timesketch_gcp_sa  = var.timesketch_gcp_sa
  namespace          = var.namespace
  timesketch_k8s_sa  = var.timesketch_k8s_sa
}

# Networking Module - VPC, NAT, firewall rules
module "networking" {
  source = "./modules/networking"

  project_id                = var.project_id
  cluster_name              = var.cluster_name
  region                    = var.region
  vpc_network               = var.vpc_network
  cluster_ipv4_cidr_block   = var.cluster_ipv4_cidr_block
  master_ipv4_cidr_block    = var.master_ipv4_cidr_block
  billing_labels            = local.billing_labels
}

# Storage Module - Filestore and GCS bucket
module "storage" {
  source = "./modules/storage"

  filestore_name        = var.filestore_name
  filestore_capacity_gb = var.filestore_capacity_gb
  zone                  = var.zone
  vpc_network           = var.vpc_network
  bucket_name           = var.bucket_name
  region                = var.region
  billing_labels        = local.billing_labels
}

# GKE Module - Cluster and node pools
module "gke" {
  source = "./modules/gke"

  project_id                   = var.project_id
  cluster_name                 = var.cluster_name
  zone                         = var.zone
  vpc_network                  = var.vpc_network
  vpc_subnetwork               = var.vpc_subnetwork
  master_ipv4_cidr_block       = var.master_ipv4_cidr_block
  cluster_ipv4_cidr_block      = var.cluster_ipv4_cidr_block
  services_ipv4_cidr_block     = var.services_ipv4_cidr_block
  base_node_count              = var.base_node_count
  base_machine_type            = var.base_machine_type
  worker_min_node_count        = var.worker_min_node_count
  worker_max_node_count        = var.worker_max_node_count
  worker_machine_type          = var.worker_machine_type
  worker_disk_size_gb          = var.worker_disk_size_gb
  disk_size_gb                 = var.disk_size_gb
  preemptible_nodes            = var.preemptible_nodes
  node_service_account_email   = module.iam.gke_node_service_account_email
  billing_labels               = local.billing_labels
  required_apis                = [for service in google_project_service.required : service]

  depends_on = [module.iam, module.networking]
}

# No PubSub module needed for Timesketch-only deployment

# Kubernetes provider for namespace creation
provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  
  # This prevents issues during initial creation when the cluster doesn't exist yet
  ignore_annotations = [
    "^kubernetes\\.io/",
  ]
  ignore_labels = [
    "^kubernetes\\.io/",
  ]
  
  # Add explicit timeouts to prevent connection issues
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gcloud"
    args = [
      "container",
      "clusters",
      "get-credentials",
      var.cluster_name,
      "--zone",
      var.zone,
      "--project",
      var.project_id
    ]
  }
}

# Helm provider for Timesketch chart installs
provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
    
    # Add explicit timeouts to prevent connection issues
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gcloud"
      args = [
        "container",
        "clusters",
        "get-credentials",
        var.cluster_name,
        "--zone",
        var.zone,
        "--project",
        var.project_id
      ]
    }
  }
}

# Kubernetes Module - K8s resources, PVs, ConfigMaps, HPAs
module "kubernetes" {
  source = "./modules/kubernetes"
  
  namespace              = var.namespace
  release_name           = var.release_name
  filestore_ip_address   = module.storage.filestore_ip_address
  filestore_capacity_gb  = var.filestore_capacity_gb
  timesketch_configs_hash = var.timesketch_configs_hash
  billing_labels         = local.billing_labels
}

# Timesketch Application Module - Helm chart deployment
module "osdfir_apps" {
  source = "./modules/apps/osdfir"

  release_name                = var.release_name
  namespace                   = module.kubernetes.namespace_name
  timesketch_config_map_name  = module.kubernetes.timesketch_config_map_name
  billing_labels              = local.billing_labels

  depends_on = [module.kubernetes]
}

# End of Timesketch deployment configuration