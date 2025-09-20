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
