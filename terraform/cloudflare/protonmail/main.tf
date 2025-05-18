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

resource "cloudflare_dns_record" "mailsec" {
  name    = var.domain
  type    = "MX"
  priority = 20
  proxied = false
  zone_id = var.zone_id
  content = "mailsec.protonmail.ch"
  ttl     = 3600
}

resource "cloudflare_dns_record" "mail" {
  name    = var.domain
  type    = "MX"
  priority = 10
  proxied = false
  zone_id = var.zone_id
  content = "mail.protonmail.ch"
  ttl     = 3600
}

resource "cloudflare_dns_record" "dmarc" {
  name    = "_dmarc"
  type    = "TXT"
  proxied = false
  zone_id = var.zone_id
  content = "v=DMARC1; p=quarantine"
  ttl     = 3600
}

resource "cloudflare_dns_record" "spf" {
  name    = var.domain
  type    = "TXT"
  proxied = false
  zone_id = var.zone_id
  content = "v=spf1 include:_spf.protonmail.ch ~all"
  ttl     = 3600
}

resource "cloudflare_dns_record" "verification" {
  name    = var.domain
  type    = "TXT"
  proxied = false
  zone_id = var.zone_id
  content = "protonmail-verification=${var.verification}"
  ttl     = 3600
}
