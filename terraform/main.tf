variable "hcloud_token" {}

provider "hcloud" {
  token = var.hcloud_token
}

locals {
  infect_userdata = file("${path.module}/infect.yaml")
  ssh_keys        = [hcloud_ssh_key.main.id]
  datacenter      = "nbg1-dc3"
  base_image      = "ubuntu-20.04"
  ssh_private_key = file("~/.ssh/id_ed25519")
}

resource "hcloud_ssh_key" "main" {
  name       = "ssh-key"
  public_key = file("~/.ssh/id_ed25519.pub")
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
  nixos_channel = "nixos-unstable"
  # flake         = "/home/julia/nix-config#andromeda"
  flake         = "github:juliamertz/nix-config/develop#andromeda"
  network_id = hcloud_network.network.id

  ssh_keys        = [hcloud_ssh_key.main.id]
  ssh_private_key = local.ssh_private_key
  hcloud_token    = var.hcloud_token
}


# module "nixos_gatekeeper" {
#   source        = "./hcloud_nixos_server"
#   name          = "gatekeeper"
#   server_type   = "cx22"
#   nixos_channel = "nixos-unstable"
#   flake         = "/home/julia/nix-config#gatekeeper"
#   # flake         = "github:juliamertz/nix-config/develop#gatekeeper"
#   network_id = hcloud_network.network.id
#
#   ssh_keys             = [hcloud_ssh_key.main.id]
#   ssh_private_key_path = "~/.ssh/id_ed25519"
#   hcloud_token         = var.hcloud_token
# }
