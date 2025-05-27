output "NIXOS_HOST_MAIN_IP" { value = module.nixos_main.ipv4_address }
output "NIXOS_HOST_MAIN_SSH_USER" { value = "root" }
output "NIXOS_HOST_MAIN_SSH_PORT" { value = 22 }

output "NIXOS_HOST_GATEKEEPER_IP" { value = module.nixos_gatekeeper.ipv4_address }
output "NIXOS_HOST_GATEKEEPER_SSH_USER" { value = "root" }
output "NIXOS_HOST_GATEKEEPER_SSH_PORT" { value = 22 }
