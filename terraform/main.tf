provider "hcloud" {
  alias = "production"
  token = var.production_hcloud_token
}

# provider "hcloud" {
#   alias = "development"
#   token = var.development_hcloud_token
# }

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
  location        = "nbg1"
  datacenter      = "nbg1-dc3"
  nixos_channel   = "nixos-unstable"
  build_on_target = data.external.host.result.system != "x86_64-linux"

  ssh_private_key = "~/.ssh/id_ed25519"
  ssh_public_key  = "~/.ssh/id_ed25519.pub"
  sops_age_key    = "~/.config/sops/age/keys.txt"

  records = {
    root            = { type = "A", name = "www" }
    grafana         = { type = "A", name = "grafana" }
    gh              = { type = "A", name = "gh" }
    wg              = { type = "A", name = "wg" }
    home-assistant  = { type = "A", name = "home-assistant" }
    nettenshop      = { type = "A", name = "nettenshop" }
    watch           = { type = "A", name = "watch" }
    cache           = { type = "A", name = "cache" }
    # nettenshop_prod = { type = "A", name = "nettenshop.prod" }
  }
}


module "production" {
  source = "./modules/hcloud/hive"

  build_on_target        = local.build_on_target
  sops_age_key           = local.sops_age_key
  deployment_private_key = "~/.ssh/id_ed25519"
  deployment_public_key  = "~/.ssh/id_ed25519.pub"
  flake_path             = var.flake_path

  providers = {
    hcloud = hcloud.production
  }
}

# module "development" {
#   source = "./modules/hcloud/hive"
#
#   build_on_target        = local.build_on_target
#   sops_age_key           = local.sops_age_key
#   deployment_private_key = "~/.ssh/id_ed25519"
#   deployment_public_key  = "~/.ssh/id_ed25519.pub"
#   flake_path             = var.flake_path
#
#   providers = {
#     hcloud = hcloud.development
#   }
# }

module "juliamertz-nl-dns" {
  source = "./modules/cloudflare/records"

  proxied         = true
  ttl             = 1
  zone_id         = var.juliamertz_nl_zone_id
  domain          = "juliamertz.nl"
  default_content = module.production.gatekeeper.ip

  records = local.records

  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-dev-dns" {
  source = "./modules/cloudflare/records"

  proxied         = true
  ttl             = 1
  zone_id         = var.juliamertz_dev_zone_id
  domain          = "juliamertz.dev"
  default_content = module.production.gatekeeper.ip

  records = local.records

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
