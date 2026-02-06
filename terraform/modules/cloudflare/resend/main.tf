module "records" {
  source = "../records"

  zone_id = var.zone_id
  domain  = var.domain

  records = {
    domain_key = {
      type    = "TXT"
      name    = "resend._domainkey"
      content = var.domain_key
    }
    send_mx = {
      type          = "MX"
      name          = "send"
      domain_suffix = false
      content       = var.smtp_url
      priority      = 10
      ttl           = 1
    }
    send_txt = {
      type          = "TXT"
      name          = "send"
      domain_suffix = false
      content       = var.spf
      ttl           = 1
    }
    dmarc = {
      type          = "TXT"
      name          = "_dmarc"
      content       = var.dmarc
      domain_suffix = true
      ttl           = 1
    }
  }

  providers = {
    cloudflare = cloudflare
  }
}
