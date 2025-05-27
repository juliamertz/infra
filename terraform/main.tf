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


module "juliamertz-nl-dns" {
  source = "./modules/cloudflare/records"

  proxied         = false
  ttl             = 300
  zone_id         = var.juliamertz_nl_zone_id
  domain          = "juliamertz.nl"
  default_content = module.hetzner_hive.gatekeeper.ip

  records = {
    www            = { type = "A", name = "www" }
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
  default_content = module.hetzner_hive.gatekeeper.ip

  records = {
    www            = { type = "A", name = "www" }
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
  source       = "./modules/cloudflare/protonmail_records"
  domain       = "juliamertz.nl"
  domain_key   = "dhrcj3l7ljct2xxjwqsdgg5s2ntzdyh2nmuqinz6mgddj2godaa2a"
  verification = "6d592d6c4efb07524737a4674938e729df1a629b"

  zone_id = var.juliamertz_nl_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-dev-email" {
  source       = "./modules/cloudflare/protonmail_records"
  domain       = "juliamertz.dev"
  domain_key   = "dhrcj3l7ljct2xxjwqsdgg5s2ntzdyh2nmuqinz6mgddj2godaa2a"
  verification = "9814917e48e94c4bf2e1a70e25a21b68d4d1e5f5"

  zone_id = var.juliamertz_dev_zone_id
  providers = {
    cloudflare = cloudflare
  }
}
