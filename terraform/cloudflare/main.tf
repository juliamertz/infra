module "juliamertz-nl" {
  source  = "./personal_domain"
  name    = "juliamertz-nl"
  ip      = var.ip_gatekeeper

  zone_id = var.juliamertz_nl_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-nl-email" {
  source = "./email"
  domain_key  = "dhrcj3l7ljct2xxjwqsdgg5s2ntzdyh2nmuqinz6mgddj2godaa2a"

  zone_id = var.juliamertz_nl_zone_id
  providers = {
    cloudflare = cloudflare
  }
}
