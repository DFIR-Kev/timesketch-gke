# PubSub Module
# This module manages Pub/Sub resources for OpenRelik

# Create Pub/Sub topic for GCS notifications
resource "google_pubsub_topic" "openrelik_gcs_notifications" {
  name = "openrelik-gcs-notifications"

  # Billing labels for cost attribution
  labels = merge(var.billing_labels, {
    component = "pubsub-topic"
    usage = "gcs-notifications"
  })
}

# Create Pub/Sub subscription for the importer
resource "google_pubsub_subscription" "openrelik_importer" {
  name  = "openrelik-importer-subscription"
  topic = google_pubsub_topic.openrelik_gcs_notifications.name

  # Configure message retention and delivery
  message_retention_duration = "604800s"  # 7 days
  retain_acked_messages      = false
  ack_deadline_seconds       = 600

  # Dead letter policy (optional)
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.openrelik_gcs_notifications.id
    max_delivery_attempts = 5
  }

  # Billing labels for cost attribution
  labels = merge(var.billing_labels, {
    component = "pubsub-subscription"
    usage = "importer-queue"
  })
}

# Grant Cloud Storage service account permission to publish to the topic
data "google_storage_project_service_account" "gcs_account" {
}

resource "google_pubsub_topic_iam_member" "storage_notification_publisher" {
  topic  = google_pubsub_topic.openrelik_gcs_notifications.id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# Grant the Pub/Sub service account permission to publish to the subscription
resource "google_pubsub_subscription_iam_member" "subscription_publisher" {
  subscription = google_pubsub_subscription.openrelik_importer.name
  role         = "roles/pubsub.editor"
  member       = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Create bucket notification to publish to Pub/Sub topic
resource "google_storage_notification" "openrelik_bucket_notification" {
  bucket         = var.bucket_name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.openrelik_gcs_notifications.id
  event_types    = ["OBJECT_FINALIZE"]

  depends_on = [google_pubsub_topic_iam_member.storage_notification_publisher]
}