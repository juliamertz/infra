# resource "cloudflare_zone_setting" "ssl_zone_setting" {
#   zone_id = var.zone_id
#   setting_id = "ssl"
#   value = "strict"
# }
#
# resource "cloudflare_zone_setting" "tls_zone_setting" {
#   zone_id = var.zone_id
#   setting_id = "tls_1_3"
#   value = "on"
# }
#
# resource "cloudflare_zone_setting" "https_rewrite_zone_setting" {
#   zone_id = var.zone_id
#   setting_id = "automatic_https_rewrites"
#   value = "on"
# }

module "subdomains" {
  source = "../records"

  proxied         = var.proxied
  ttl             = var.ttl
  zone_id         = var.zone_id
  domain          = var.domain
  default_content = var.ip

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
