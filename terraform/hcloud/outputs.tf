output "main" {
  value = {
    ip       = module.nixos_main.ipv4_address
    ssh_port = 22
    ssh_user = "root"
  }
}

output "gatekeeper" {
  value = {
    ip       = module.nixos_gatekeeper.ipv4_address
    ssh_port = 22
    ssh_user = "root"
  }
}
