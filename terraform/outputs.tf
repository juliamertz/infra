output "NIXOS_HOST_GATEKEEPER_IP" { value = module.production.gatekeeper.ip }
output "NIXOS_HOST_GATEKEEPER_SSH_USER" { value = "root" }
output "NIXOS_HOST_GATEKEEPER_SSH_PORT" { value = 22 }

output "NIXOS_HOST_TOPDOG_IP" { value = module.production.topdog.ip }
output "NIXOS_HOST_TOPDOG_SSH_USER" { value = "root" }
output "NIXOS_HOST_TOPDOG_SSH_PORT" { value = 22 }

output "NIXOS_HOST_CUBE_IP" { value = module.production.cube.ip }
output "NIXOS_HOST_CUBE_SSH_USER" { value = "root" }
output "NIXOS_HOST_CUBE_SSH_PORT" { value = 22 }
