# GKE Cluster Module
# This module manages the GKE cluster and node pools

# Create GKE cluster
# This cluster is protected from deletion to prevent accidental removal
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  # Remove default node pool immediately
  remove_default_node_pool = true
  initial_node_count       = 1

  # Prevent accidental deletion
  deletion_protection = true

  # Network configuration
  network    = var.vpc_network
  subnetwork = var.vpc_subnetwork

  # Master auth configuration
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Network policy
  network_policy {
    enabled = true
  }

  # Enable required addons
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  # Logging and monitoring - relying on these to correctly provision the Metrics Server
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    master_ipv4_cidr_block = var.master_ipv4_cidr_block
  }

  # Billing labels for cost attribution
  resource_labels = var.billing_labels

  depends_on = [var.required_apis]
}

# Create BASE node pool (always-on for core services)
resource "google_container_node_pool" "base_nodes" {
  name       = "${var.cluster_name}-base-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.base_node_count

  node_config {
    preemptible  = false  # Base nodes should not be preemptible
    machine_type = var.base_machine_type
    disk_size_gb = var.disk_size_gb

    # Google Cloud service account
    service_account = var.node_service_account_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Security
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Enhanced labels for billing and management
    labels = merge(var.billing_labels, {
      pool        = "base"
      component   = "gke-base-nodes"
      workload    = "core-services"
      cost-tier   = "always-on"
    })

    tags = ["osdfir-base-nodes"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Create WORKER node pool (autoscaling for compute-intensive workloads)
resource "google_container_node_pool" "worker_nodes" {
  name       = "${var.cluster_name}-worker-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  version    = google_container_cluster.primary.min_master_version
  node_count = 0 # Start with 0 nodes, scale up as needed

  # Enable autoscaling for worker pool by defining the block
  autoscaling {
    min_node_count = var.worker_min_node_count
    max_node_count = var.worker_max_node_count
  }

  node_config {
    preemptible  = var.preemptible_nodes  # Use preemptible for cost savings
    machine_type = var.worker_machine_type
    disk_size_gb = var.worker_disk_size_gb

    # Google Cloud service account
    service_account = var.node_service_account_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Security
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Enhanced labels for billing and management
    labels = merge(var.billing_labels, {
      pool        = "worker"
      component   = "gke-worker-nodes"
      workload    = "compute-intensive"
      cost-tier   = "autoscaling"
      preemptible = var.preemptible_nodes ? "true" : "false"
    })

    tags = ["osdfir-worker-nodes"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}