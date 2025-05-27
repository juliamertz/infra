locals {
  datacenter    = "nbg1-dc3"
  nixos_channel = "nixos-unstable"

  // TODO: these should be configurable
  // also rename them something like deployment_private_key, ...
  ssh_private_key = file("~/.ssh/id_ed25519")
  ssh_public_key  = file("~/.ssh/id_ed25519.pub")
  sops_age_key    = file("~/.config/sops/age/keys.txt")

  ssh_keys = [hcloud_ssh_key.julia.id]
}

resource "hcloud_ssh_key" "julia" {
  name       = "ssh-key-julia"
  public_key = local.ssh_public_key
}

resource "hcloud_network" "network" {
  name     = "network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "internal" {
  network_id   = hcloud_network.network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

module "nixos_gatekeeper" {
  source      = "./nixos_server"
  name        = "gatekeeper"
  server_type = "cx22"
  datacenter  = local.datacenter

  network_id  = hcloud_network.network.id
  internal_ip = "10.0.1.1"
  public_ip   = true

  nixos_channel   = local.nixos_channel
  flake_path      = var.flake_path
  flake_profile   = "gatekeeper"
  build_on_target = var.build_on_target

  ssh_keys        = local.ssh_keys
  ssh_private_key = local.ssh_private_key
  sops_age_key    = local.sops_age_key

  providers = {
    hcloud = hcloud
  }
}

module "nixos_main" {
  source      = "./nixos_server"
  name        = "main"
  server_type = "cpx21"

  datacenter  = local.datacenter
  network_id  = hcloud_network.network.id
  internal_ip = "10.0.1.2"
  public_ip   = true

  nixos_channel   = local.nixos_channel
  flake_path      = var.flake_path
  flake_profile   = "main"
  build_on_target = var.build_on_target

  ssh_keys        = local.ssh_keys
  ssh_private_key = local.ssh_private_key
  sops_age_key    = local.sops_age_key

  providers = {
    hcloud = hcloud
  }
}

