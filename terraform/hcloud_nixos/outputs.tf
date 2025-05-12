output "hostname" {
  description = "Hostname of the server"
  value       = var.name
}

output "server_id" {
  description = "ID of the created server"
  value       = hcloud_server.server.id
}

output "ipv4_address" {
  description = "IPv4 address of the server"
  value       = hcloud_server.server.ipv4_address
}

output "ipv6_address" {
  description = "IPv6 address of the server"
  value       = hcloud_server.server.ipv6_address
}

output "status" {
  description = "Status of the server"
  value       = hcloud_server.server.status
}
