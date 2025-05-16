provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

module "hetzner_hive" {
  source      = "./hcloud"
  local_build = false
  flake_path  = "../"

  providers = {
    hcloud = hcloud
  }
}

module "cloudflare_dns" {
  source        = "./cloudflare"
  ip_gatekeeper = module.hetzner_hive.gatekeeper.ip
  ip_main       = module.hetzner_hive.main.ip

  providers = {
    cloudflare = cloudflare
  }
}
