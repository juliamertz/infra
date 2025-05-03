variable "hcloud_token" {}

provider "hcloud" {
  token = var.hcloud_token
}

locals {
  datacenter = "nbg1-dc3"
  base_image = "ubuntu-20.04"

  flake_path_local  = "/home/julia/nix-config"
  flake_path_github = "github:juliamertz/nix-config/develop"

  ssh_private_key = file("~/.ssh/id_ed25519")
  ssh_public_key  = file("~/.ssh/id_ed25519.pub")
  ssh_keys        = [hcloud_ssh_key.julia.id]
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
  source        = "./hcloud_nixos_server"
  name          = "main"
  server_type   = "cpx21"
  nixos_channel = "nixos-24.05"
  flake         = "${local.flake_path_github}#andromeda"
  network_id    = hcloud_network.network.id

  ssh_keys        = [hcloud_ssh_key.julia.id]
  ssh_private_key = local.ssh_private_key
  hcloud_token    = var.hcloud_token
}

module "nixos_gatekeeper" {
  source        = "./hcloud_nixos_server"
  name          = "gatekeeper"
  server_type   = "cx22"
  nixos_channel = "nixos-24.05"
  flake         = "${local.flake_path_github}#gatekeeper"
  network_id    = hcloud_network.network.id

  ssh_keys        = [hcloud_ssh_key.julia.id]
  ssh_private_key = local.ssh_private_key
  hcloud_token    = var.hcloud_token
}
