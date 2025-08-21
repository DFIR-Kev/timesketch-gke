# OSDFIR Applications Module Outputs

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = helm_release.osdfir.name
}

output "helm_release_namespace" {
  description = "Namespace of the Helm release"
  value       = helm_release.osdfir.namespace
}

output "helm_release_version" {
  description = "Version of the Helm release"
  value       = helm_release.osdfir.version
}