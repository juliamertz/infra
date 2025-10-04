output "ENV" {
  value = {
    NIXOS_HOST_TOPDOG_IP = module.production.topdog.ip
    NIXOS_HOST_TOPDOG_SSH_USER = "root"
    NIXOS_HOST_TOPDOG_SSH_PORT = 22

    NIXOS_HOST_GATEKEEPER_IP = module.production.gatekeeper.ip
    NIXOS_HOST_GATEKEEPER_SSH_USER = "root"
    NIXOS_HOST_GATEKEEPER_SSH_PORT = 22
  }
}

output "talosconfig" {
  value     = module.production_k8s.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.production_k8s.kubeconfig
  sensitive = true
}


output "talos_machine_configurations_control_plane" {
  value     = module.production_k8s.talos_machine_configurations_control_plane
  sensitive = true
}

output "talos_machine_configurations_worker" {
  value     = module.production_k8s.talos_machine_configurations_worker
  sensitive = true
}
