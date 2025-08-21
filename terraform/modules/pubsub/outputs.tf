# PubSub Module Outputs

output "topic_name" {
  description = "Name of the Pub/Sub topic for GCS notifications"
  value       = google_pubsub_topic.openrelik_gcs_notifications.name
}

output "topic_id" {
  description = "ID of the Pub/Sub topic for GCS notifications"
  value       = google_pubsub_topic.openrelik_gcs_notifications.id
}

output "subscription_name" {
  description = "Name of the Pub/Sub subscription for the importer"
  value       = google_pubsub_subscription.openrelik_importer.name
}

output "subscription_id" {
  description = "ID of the Pub/Sub subscription for the importer"
  value       = google_pubsub_subscription.openrelik_importer.id
}