module "juliamertz-nl" {
  source  = "./hive_dns"
  name    = "juliamertz-nl"
  ip      = var.ip_gatekeeper
  ttl     = 300
  proxied = false

  zone_id = var.juliamertz_nl_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-nl-email" {
  source       = "./protonmail"
  domain       = "juliamertz.nl"
  domain_key   = "dhrcj3l7ljct2xxjwqsdgg5s2ntzdyh2nmuqinz6mgddj2godaa2a"
  verification = "6d592d6c4efb07524737a4674938e729df1a629b"

  zone_id = var.juliamertz_nl_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-dev" {
  source  = "./hive_dns"
  name    = "juliamertz-dev"
  ip      = var.ip_gatekeeper
  ttl     = 300
  proxied = false

  zone_id = var.juliamertz_dev_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-dev-email" {
  source       = "./protonmail"
  domain       = "juliamertz.dev"
  domain_key   = "dhrcj3l7ljct2xxjwqsdgg5s2ntzdyh2nmuqinz6mgddj2godaa2a"
  verification = "9814917e48e94c4bf2e1a70e25a21b68d4d1e5f5"

  zone_id = var.juliamertz_dev_zone_id
  providers = {
    cloudflare = cloudflare
  }
}
