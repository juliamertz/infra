resource "hcloud_ssh_key" "julia" {
  name       = "ssh-key-julia"
  public_key = file(var.deployment_public_key)
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

resource "hcloud_volume" "persisted" {
  name     = "persisted"
  size     = 10
  format   = "ext4"
  location = var.location

  delete_protection = true
  lifecycle {
    prevent_destroy = true
  }
}

module "nixos_gatekeeper" {
  source      = "../nixos_server"
  name        = "gatekeeper"
  server_type = "cx22"
  datacenter  = var.datacenter

  network_id  = hcloud_network.network.id
  internal_ip = "10.0.1.1"
  public_ip   = true

  nixos_channel   = var.nixos_channel
  flake_path      = var.flake_path
  flake_profile   = "gatekeeper"
  build_on_target = var.build_on_target

  ssh_keys        = [hcloud_ssh_key.julia.id]
  ssh_private_key = file(var.deployment_private_key)
  sops_age_key    = var.sops_age_key

  providers = {
    hcloud = hcloud
  }
}

module "nixos_topdog" {
  source      = "../nixos_server"
  name        = "topdog"
  server_type = "cx32"

  datacenter  = var.datacenter
  network_id  = hcloud_network.network.id
  internal_ip = "10.0.1.3"
  public_ip   = true

  nixos_channel   = var.nixos_channel
  flake_path      = var.flake_path
  flake_profile   = "topdog"
  build_on_target = var.build_on_target

  ssh_keys        = [hcloud_ssh_key.julia.id]
  ssh_private_key = file(var.deployment_private_key)
  sops_age_key    = var.sops_age_key

  providers = {
    hcloud = hcloud
  }
}

resource "hcloud_volume_attachment" "topdog_persisted" {
  volume_id = hcloud_volume.persisted.id
  server_id = module.nixos_topdog.server_id
  automount = false
}


# module "nixos_cube" {
#   source      = "../nixos_server"
#   name        = "cube"
#   server_type = "cax31"
#
#   datacenter  = var.datacenter
#   network_id  = hcloud_network.network.id
#   internal_ip = "10.0.1.4"
#   public_ip   = true
#
#   nixos_channel   = var.nixos_channel
#   flake_path      = var.flake_path
#   flake_profile   = "cube"
#   build_on_target = var.build_on_target
#
#   ssh_keys        = [hcloud_ssh_key.julia.id]
#   ssh_private_key = file(var.deployment_private_key)
#   sops_age_key    = var.sops_age_key
#
#   providers = {
#     hcloud = hcloud
#   }
# }
