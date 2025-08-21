# IAM Module
# This module manages service accounts and IAM permissions

# Create service accounts
resource "google_service_account" "gke_node_sa" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
}

resource "google_service_account" "timesketch_sa" {
  account_id   = var.timesketch_gcp_sa
  display_name = "Timesketch GCP Service Account"
}

# IAM bindings for node service account
resource "google_project_iam_member" "gke_node_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# IAM bindings for Timesketch service account
resource "google_project_iam_member" "timesketch_sa_roles" {
  for_each = toset([
    "roles/storage.objectViewer",
    "roles/storage.objectCreator",
    "roles/artifactregistry.reader"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.timesketch_sa.email}"
}

# Workload Identity binding for Timesketch
resource "google_service_account_iam_member" "timesketch_workload_identity_binding" {
  service_account_id = google_service_account.timesketch_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.timesketch_k8s_sa}]"
}