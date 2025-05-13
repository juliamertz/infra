module "juliamertz-nl" {
  source  = "./personal_domain"
  name    = "juliamertz-nl"
  zone_id = var.juliamertz_nl_zone_id
  ip      = var.ip_gatekeeper

  providers = {
    cloudflare = cloudflare
  }
}
