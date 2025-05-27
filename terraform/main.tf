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

module "hetzner_hive" {
  source          = "./hcloud"
  build_on_target = data.external.host.result.system != "x86_64-linux"
  flake_path      = "../"

  providers = {
    hcloud = hcloud
  }
}

# module "cloudflare_dns" {
#   source        = "./cloudflare"
#   ip_gatekeeper = module.hetzner_hive.gatekeeper.ip
#   ip_main       = module.hetzner_hive.main.ip
#
#   providers = {
#     cloudflare = cloudflare
#   }
# }

variable "cloudflare_account_id" {
  type    = string
  default = "2b3473f287c2ddf45a7105b22e69c7a9"
}

variable "juliamertz_dev_zone_id" {
  type    = string
  default = "e449c68d1df84fc7e9791540989c3304"
}

variable "juliamertz_nl_zone_id" {
  type    = string
  default = "6848c25638c792b4251cc08c91676137"
}


module "juliamertz-nl" {
  source  = "./modules/cloudflare/hive_dns"
  name    = "juliamertz-nl"
  domain  = "juliamertz.nl"
  ip      = module.hetzner_hive.gatekeeper.ip
  ttl     = 300
  proxied = false

  zone_id = var.juliamertz_nl_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-nl-email" {
  source       = "./cloudflare/protonmail"
  domain       = "juliamertz.nl"
  domain_key   = "dhrcj3l7ljct2xxjwqsdgg5s2ntzdyh2nmuqinz6mgddj2godaa2a"
  verification = "6d592d6c4efb07524737a4674938e729df1a629b"

  zone_id = var.juliamertz_nl_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-dev" {
  source  = "./modules/cloudflare/hive_dns"
  name    = "juliamertz-dev"
  domain  = "juliamertz.dev"
  ip      = module.hetzner_hive.gatekeeper.ip
  ttl     = 300
  proxied = false

  zone_id = var.juliamertz_dev_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-dev-email" {
  source       = "./cloudflare/protonmail"
  domain       = "juliamertz.dev"
  domain_key   = "dhrcj3l7ljct2xxjwqsdgg5s2ntzdyh2nmuqinz6mgddj2godaa2a"
  verification = "9814917e48e94c4bf2e1a70e25a21b68d4d1e5f5"

  zone_id = var.juliamertz_dev_zone_id
  providers = {
    cloudflare = cloudflare
  }
}
