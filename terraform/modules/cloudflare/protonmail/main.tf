module "records" {
  source = "../records"

  zone_id = var.zone_id
  domain  = var.domain

  records = {
    domain_key_1 = {
      type    = "CNAME"
      name    = "protonmail._domainkey"
      content = "protonmail.domainkey.${var.domain_key}.domains.proton.ch"
    }
    domain_key_2 = {
      type    = "CNAME"
      name    = "protonmail2._domainkey"
      content = "protonmail2.domainkey.${var.domain_key}.domains.proton.ch"
    }
    domain_key_3 = {
      type    = "CNAME"
      name    = "protonmail3._domainkey"
      content = "protonmail3.domainkey.${var.domain_key}.domains.proton.ch"
    }
    mailsec = {
      type     = "MX"
      name     = var.domain
      domain_suffix  = false
      content  = "mailsec.protonmail.ch"
      priority = 20
      ttl      = 300
    }
    mail = {
      type     = "MX"
      name     = var.domain
      domain_suffix  = false
      content  = "mail.protonmail.ch"
      priority = 10
      ttl      = 300
    }
    // TODO: auto qoute TXT records
    dmarc = {
      type    = "TXT"
      name    = "_dmarc"
      content = "\"v=DMARC1; p=quarantine\""
      ttl     = 300
    }
    spf = {
      type    = "TXT"
      name    = var.domain
      domain_suffix  = false
      content = "\"v=spf1 include:_spf.protonmail.ch ~all\""
      ttl     = 300
    }
    verification = {
      type    = "TXT"
      name    = var.domain
      domain_suffix  = false
      content = "\"protonmail-verification=${var.verification}\""
      ttl     = 300
    }
  }

  providers = {
    cloudflare = cloudflare
  }
}
