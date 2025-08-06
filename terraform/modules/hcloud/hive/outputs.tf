output "gatekeeper" {
  value = {
    ip = module.nixos_gatekeeper.ipv4_address
  }
}


output "topdog" {
  value = {
    ip = module.nixos_topdog.ipv4_address
  }
}

output "cube" {
  value = {
    ip = module.nixos_cube.ipv4_address
  }
}

