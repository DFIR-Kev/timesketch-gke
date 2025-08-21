# Networking Module
# This module manages networking resources for the GKE cluster

# Look up the existing VPC by name
data "google_compute_network" "osdfir_vpc" {
  name    = var.vpc_network
  project = var.project_id
}

# Cloud Router + NAT for private cluster egress
resource "google_compute_router" "nat_router" {
  name    = "${var.cluster_name}-nat-router"
  region  = var.region
  network = data.google_compute_network.osdfir_vpc.self_link

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_router_nat" "private_nat" {
  name                               = "${var.cluster_name}-nat-gateway"
  router                             = google_compute_router.nat_router.name
  region                             = google_compute_router.nat_router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "TRANSLATIONS_ONLY"
  }
}

# Reserve a global static IP for Ingress
resource "google_compute_global_address" "ingress_ip" {
  name         = "osdfir-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  # Billing labels for cost attribution
  labels = merge(var.billing_labels, {
    component = "static-ip"
    usage = "ingress"
  })
}

# Firewall to allow NFS mount to Filestore
resource "google_compute_firewall" "filestore_nfs" {
  name    = "allow-osdfir-filestore"
  network = var.vpc_network

  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  source_ranges = [var.cluster_ipv4_cidr_block]
  description   = "Allow nodes to mount Filestore via NFS"
}

# Allow the GKE control plane to access the Metrics Server on nodes
resource "google_compute_firewall" "gke_control_plane_to_metrics" {
  name    = "${var.cluster_name}-cp-to-metrics"
  network = var.vpc_network

  allow {
    protocol = "tcp"
    ports    = ["4443"]
  }

  source_ranges = [var.master_ipv4_cidr_block]
  target_tags   = ["gke-${var.cluster_name}-node"]
  description   = "Allow GKE control plane to access the Metrics Server for HPA"
}