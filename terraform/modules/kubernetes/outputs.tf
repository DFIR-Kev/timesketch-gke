# Kubernetes Module Outputs

output "namespace_name" {
  description = "Name of the OSDFIR namespace"
  value       = kubernetes_namespace.osdfir.metadata[0].name
}

output "pvc_name" {
  description = "Name of the shared PVC"
  value       = kubernetes_persistent_volume_claim.osdfirvolume.metadata[0].name
}

output "timesketch_config_map_name" {
  description = "Name of the Timesketch ConfigMap"
  value       = kubernetes_config_map.timesketch_configs.metadata[0].name
}

output "storage_class_name" {
  description = "Name of the NFS storage class"
  value       = kubernetes_storage_class.nfs_rwx.metadata[0].name
}