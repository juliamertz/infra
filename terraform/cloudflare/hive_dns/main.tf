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
  source = "../../modules/cloudflare/subdomain_records"

  proxied = var.proxied
  ttl     = var.ttl
  zone_id = var.zone_id
  domain  = var.domain
  default_content = var.ip

  records = {
    www = {
      name    = "www"
      type    = "A"
    }
    grafana = {
      name    = "grafana"
      type    = "A"
    }
    gh = {
      name    = "gh"
      type    = "A"
    }
    home-assistant = {
      name    = "home-assistant"
      type    = "A"
    }
    nettenshop = {
      name    = "nettenshop"
      type    = "A"
    }
    watch = {
      name    = "watch"
      type    = "A"
    }
    cache = {
      name    = "cache"
      type    = "A"
    }
  }

  providers = {
    cloudflare = cloudflare
  }
}
