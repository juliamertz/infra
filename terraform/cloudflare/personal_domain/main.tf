resource "cloudflare_zone_settings_override" "zone-settings" {
  zone_id = var.zone_id
  settings {
    ssl                      = "strict"
    tls_1_3                  = "on"
    automatic_https_rewrites = "on"
  }
}

resource "cloudflare_record" "www" {
  name    = "www"
  type    = "A"
  proxied = false
  zone_id = var.zone_id
  content = "188.245.65.183"
}

resource "cloudflare_record" "grafana" {
  name    = "grafana"
  type    = "A"
  proxied = false
  zone_id = var.zone_id
  content = var.ip
}

resource "cloudflare_record" "gh" {
  name    = "gh"
  type    = "A"
  proxied = false
  zone_id = var.zone_id
  content = var.ip
}

resource "cloudflare_record" "home-assistant" {
  name    = "home-assistant"
  type    = "A"
  proxied = false
  zone_id = var.zone_id
  content = var.ip
}

resource "cloudflare_record" "nettenshop" {
  name    = "nettenshop"
  type    = "A"
  proxied = false
  zone_id = var.zone_id
  content = var.ip
}

resource "cloudflare_record" "watch" {
  name    = "watch"
  type    = "A"
  proxied = false
  zone_id = var.zone_id
  content = var.ip
}

resource "cloudflare_record" "cache" {
  name    = "cache"
  type    = "A"
  proxied = false
  zone_id = var.zone_id
  content = var.ip
}

