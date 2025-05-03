provider "hcloud" {
  token = var.hcloud_token
}

locals {
  datacenter    = "nbg1-dc3"
  nixos_channel = "nixos-24.11"

  flake_path_local  = "/home/julia/infra"
  flake_path_github = "github:juliamertz/infra"

  ssh_private_key = file("~/.ssh/id_ed25519")
  ssh_public_key  = file("~/.ssh/id_ed25519.pub")
}

resource "hcloud_ssh_key" "julia" {
  name       = "ssh-key"
  public_key = local.ssh_public_key
}

resource "hcloud_network" "network" {
  name     = "network"
  ip_range = "10.0.1.0/24"
}

resource "hcloud_network_subnet" "internal" {
  network_id   = hcloud_network.network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

module "nixos_main" {
  source      = "./hcloud_nixos_server"
  name        = "main"
  server_type = "cpx21"
  datacenter  = local.datacenter
  network_id  = hcloud_network.network.id

  flake         = "${local.flake_path_github}#main"
  nixos_channel = local.nixos_channel

  ssh_keys        = [hcloud_ssh_key.julia.id]
  ssh_private_key = local.ssh_private_key
  hcloud_token    = var.hcloud_token
}

module "nixos_gatekeeper" {
  source      = "./hcloud_nixos_server"
  name        = "gatekeeper"
  server_type = "cx22"
  datacenter  = local.datacenter
  network_id  = hcloud_network.network.id

  flake         = "${local.flake_path_github}#gatekeeper"
  nixos_channel = local.nixos_channel

  ssh_keys        = [hcloud_ssh_key.julia.id]
  ssh_private_key = local.ssh_private_key
  hcloud_token    = var.hcloud_token
}
