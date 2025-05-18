resource "cloudflare_dns_record" "www" {
  name    = "www"
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

