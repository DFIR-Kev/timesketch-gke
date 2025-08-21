# Networking Module Outputs

output "vpc_network" {
  description = "The VPC network"
  value       = data.google_compute_network.osdfir_vpc
}

output "nat_router_name" {
  description = "Name of the Cloud NAT router"
  value       = google_compute_router.nat_router.name
}

output "nat_gateway_name" {
  description = "Name of the Cloud NAT gateway"
  value       = google_compute_router_nat.private_nat.name
}

output "ingress_ip_address" {
  description = "The reserved static IP address for ingress"
  value       = google_compute_global_address.ingress_ip.address
}

output "ingress_ip_name" {
  description = "Name of the reserved static IP"
  value       = google_compute_global_address.ingress_ip.name
}