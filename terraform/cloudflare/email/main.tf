resource "cloudflare_dns_record" "domain_key_1" {
  name    = "protonmail._domainkey"
  type    = "CNAME"
  proxied = true
  zone_id = var.zone_id
  content = "protonmail.domainkey.${var.domain_key}.domains.proton.ch"
  ttl     = 1
}

resource "cloudflare_dns_record" "domain_key_2" {
  name    = "protonmail2._domainkey"
  type    = "CNAME"
  proxied = true
  zone_id = var.zone_id
  content = "protonmail2.domainkey.${var.domain_key}.domains.proton.ch"
  ttl     = 1
}

resource "cloudflare_dns_record" "domain_key_3" {
  name    = "protonmail3._domainkey"
  type    = "CNAME"
  proxied = true
  zone_id = var.zone_id
  content = "protonmail3.domainkey.${var.domain_key}.domains.proton.ch"
  ttl     = 1
}
