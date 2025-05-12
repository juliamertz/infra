provider "hcloud" {
  token = var.hcloud_token
}

locals {
  datacenter    = "nbg1-dc3"
  nixos_channel = "nixos-unstable"

  repo_path   = ".."
  config_path = "${local.repo_path}/hive"

  flake_path_local  = "/home/julia/infra"
  flake_path_github = "github:juliamertz/infra"
  flake_path        = local.flake_path_local

  ssh_private_key = file("~/.ssh/id_ed25519")
  ssh_public_key  = file("~/.ssh/id_ed25519.pub")
  ssh_keys        = [hcloud_ssh_key.julia.id]

  sops_age_key = file("~/.config/sops/age/keys.txt")
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

resource "hcloud_floating_ip" "entrypoint" {
  type      = "ipv4"
  server_id = module.nixos_gatekeeper.server_id

  lifecycle {
    prevent_destroy = true
  }
}

module "nixos_gatekeeper" {
  source      = "./hcloud_nixos"
  name        = "gatekeeper"
  server_type = "cx22"
  datacenter  = local.datacenter

  network_id = hcloud_network.network.id
  public_ip  = true

  nixos_channel     = local.nixos_channel
  local_flake_path  = local.flake_path_local
  remote_flake_path = local.flake_path_github
  flake_profile     = "gatekeeper"
  local_build       = false

  ssh_keys        = local.ssh_keys
  ssh_private_key = local.ssh_private_key
  sops_age_key    = local.sops_age_key
  hcloud_token    = var.hcloud_token
}

output "nixos_gatekeeper" {
  value = {
    _type = "nixos_host"

    config   = "${local.config_path}/gatekeeper.nix"
    hostname = module.nixos_gatekeeper.hostname
    ip       = module.nixos_gatekeeper.ipv4_address
  }
}

module "nixos_main" {
  source      = "./hcloud_nixos"
  name        = "main"
  server_type = "cpx21"

  datacenter = local.datacenter
  network_id = hcloud_network.network.id
  public_ip  = true

  nixos_channel     = local.nixos_channel
  local_flake_path  = local.flake_path_local
  remote_flake_path = local.flake_path_github
  flake_profile     = "main"
  local_build       = false

  ssh_keys        = local.ssh_keys
  ssh_private_key = local.ssh_private_key
  sops_age_key    = local.sops_age_key
  hcloud_token    = var.hcloud_token
}

output "nixos_main" {
  value = {
    _type = "nixos_host"

    config   = "${local.config_path}/main.nix"
    hostname = module.nixos_main.hostname
    ip       = module.nixos_main.ipv4_address
  }
}
