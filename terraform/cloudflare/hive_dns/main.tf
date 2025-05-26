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

resource "cloudflare_dns_record" "www" {
  name    = "www"
  type    = "A"
  proxied = var.proxied
  zone_id = var.zone_id
  content = "188.245.65.183"
  ttl     = var.ttl
}

resource "cloudflare_dns_record" "grafana" {
  name    = "grafana"
  type    = "A"
  proxied = var.proxied
  zone_id = var.zone_id
  content = var.ip
  ttl     = var.ttl
}

resource "cloudflare_dns_record" "gh" {
  name    = "gh"
  type    = "A"
  proxied = var.proxied
  zone_id = var.zone_id
  content = var.ip
  ttl     = var.ttl
}

resource "cloudflare_dns_record" "home-assistant" {
  name    = "home-assistant"
  type    = "A"
  proxied = var.proxied
  zone_id = var.zone_id
  content = var.ip
  ttl     = var.ttl
}

resource "cloudflare_dns_record" "nettenshop" {
  name    = "nettenshop"
  type    = "A"
  proxied = var.proxied
  zone_id = var.zone_id
  content = var.ip
  ttl     = var.ttl
}

resource "cloudflare_dns_record" "watch" {
  name    = "watch"
  type    = "A"
  proxied = var.proxied
  zone_id = var.zone_id
  content = var.ip
  ttl     = var.ttl
}

resource "cloudflare_dns_record" "cache" {
  name    = "cache"
  type    = "A"
  proxied = var.proxied
  zone_id = var.zone_id
  content = var.ip
  ttl     = var.ttl
}

