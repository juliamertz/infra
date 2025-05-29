output "NIXOS_HOST_GATEKEEPER_IP" { value = module.development.gatekeeper.ip }
output "NIXOS_HOST_GATEKEEPER_SSH_USER" { value = "root" }
output "NIXOS_HOST_GATEKEEPER_SSH_PORT" { value = 22 }

output "NIXOS_HOST_TOPDOG_IP" { value = module.development.topdog.ip }
output "NIXOS_HOST_TOPDOG_SSH_USER" { value = "root" }
output "NIXOS_HOST_TOPDOG_SSH_PORT" { value = 22 }
