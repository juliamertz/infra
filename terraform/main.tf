provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

data "external" "host" {
  program = [
    "nix",
    "eval",
    "--impure",
    "--raw",
    "--expr",
    "builtins.toJSON { system = builtins.currentSystem; }",
  ]
}

locals {
  datacenter      = "nbg1-dc3"
  nixos_channel   = "nixos-unstable"
  build_on_target = data.external.host.result.system != "x86_64-linux"

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
  source      = "./modules/hcloud/nixos_server"
  name        = "gatekeeper"
  server_type = "cx22"
  datacenter  = local.datacenter

  network_id  = hcloud_network.network.id
  internal_ip = "10.0.1.1"
  public_ip   = true

  nixos_channel   = local.nixos_channel
  flake_path      = var.flake_path
  flake_profile   = "gatekeeper"
  build_on_target = local.build_on_target

  ssh_keys        = local.ssh_keys
  ssh_private_key = local.ssh_private_key
  sops_age_key    = local.sops_age_key

  providers = {
    hcloud = hcloud
  }
}

module "nixos_topdog" {
  source      = "./modules/hcloud/nixos_server"
  name        = "topdog"
  server_type = "cx32"

  datacenter  = local.datacenter
  network_id  = hcloud_network.network.id
  internal_ip = "10.0.1.3"
  public_ip   = true

  nixos_channel   = local.nixos_channel
  flake_path      = var.flake_path
  flake_profile   = "topdog"
  build_on_target = local.build_on_target

  ssh_keys        = local.ssh_keys
  ssh_private_key = local.ssh_private_key
  sops_age_key    = local.sops_age_key

  providers = {
    hcloud = hcloud
  }
}

module "juliamertz-nl-dns" {
  source = "./modules/cloudflare/records"

  proxied         = false
  ttl             = 300
  zone_id         = var.juliamertz_nl_zone_id
  domain          = "juliamertz.nl"
  default_content = module.nixos_gatekeeper.ipv4_address

  records = {
    root           = { type = "A", name = "www" }
    grafana        = { type = "A", name = "grafana" }
    gh             = { type = "A", name = "gh" }
    home-assistant = { type = "A", name = "home-assistant" }
    nettenshop     = { type = "A", name = "nettenshop" }
    watch          = { type = "A", name = "watch" }
    cache          = { type = "A", name = "cache" }
  }

  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-dev-dns" {
  source = "./modules/cloudflare/records"

  proxied         = false
  ttl             = 300
  zone_id         = var.juliamertz_dev_zone_id
  domain          = "juliamertz.dev"
  default_content = module.nixos_gatekeeper.ipv4_address

  records = {
    root           = { type = "A", name = "www" }
    grafana        = { type = "A", name = "grafana" }
    gh             = { type = "A", name = "gh" }
    home-assistant = { type = "A", name = "home-assistant" }
    nettenshop     = { type = "A", name = "nettenshop" }
    watch          = { type = "A", name = "watch" }
    cache          = { type = "A", name = "cache" }
  }

  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-nl-email" {
  source       = "./modules/cloudflare/protonmail"
  domain       = "juliamertz.nl"
  domain_key   = "d3u5rtsm5vj2kjzwcua5sns57x4p62m3wlapug7zjtnpps2x4ayoa"
  verification = "6d592d6c4efb07524737a4674938e729df1a629b"

  zone_id = var.juliamertz_nl_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-dev-email" {
  source       = "./modules/cloudflare/protonmail"
  domain       = "juliamertz.dev"
  domain_key   = "dhrcj3l7ljct2xxjwqsdgg5s2ntzdyh2nmuqinz6mgddj2godaa2a"
  verification = "9814917e48e94c4bf2e1a70e25a21b68d4d1e5f5"

  zone_id = var.juliamertz_dev_zone_id
  providers = {
    cloudflare = cloudflare
  }
}
