# Storage Module
# This module manages Filestore and GCS bucket resources

# Create Filestore instance for shared storage
resource "google_filestore_instance" "osdfir_filestore" {
  name     = var.filestore_name
  location = var.zone
  tier     = "STANDARD"

  file_shares {
    capacity_gb = var.filestore_capacity_gb
    name        = "vol1"
  }

  networks {
    network = var.vpc_network
    modes   = ["MODE_IPV4"]
  }

  # Billing labels for cost attribution
  labels = merge(var.billing_labels, {
    component = "filestore"
    storage-type = "nfs"
    usage = "shared-storage"
  })
}

# Create Google Cloud Storage bucket for Timesketch data
# WARNING: This bucket contains forensic data
resource "google_storage_bucket" "timesketch_data" {
  name     = var.bucket_name
  location = var.region

  uniform_bucket_level_access = true
  force_destroy = false  # Explicitly set to false to prevent accidental deletion

  versioning {
    enabled = false
  }

  # Prevent destruction of the bucket to avoid data loss
  lifecycle {
    prevent_destroy = true
  }

  labels = merge(var.billing_labels, {
    component     = "gcs-bucket"
    storage-type  = "object"
    usage         = "timesketch-data"
  })
}