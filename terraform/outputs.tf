output "NIXOS_HOST_MAIN_IP" { value = module.hetzner_hive.main.ip }
output "NIXOS_HOST_MAIN_SSH_USER" { value = module.hetzner_hive.main.ssh_user }
output "NIXOS_HOST_MAIN_SSH_PORT" { value = module.hetzner_hive.main.ssh_port }

output "NIXOS_HOST_GATEKEEPER_IP" { value = module.hetzner_hive.gatekeeper.ip }
output "NIXOS_HOST_GATEKEEPER_SSH_USER" { value = module.hetzner_hive.gatekeeper.ssh_user }
output "NIXOS_HOST_GATEKEEPER_SSH_PORT" { value = module.hetzner_hive.gatekeeper.ssh_port }

