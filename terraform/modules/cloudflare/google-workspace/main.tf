module "records" {
  source = "../records"

  zone_id = var.zone_id
  domain  = var.domain

  records = {
    mx = {
      type          = "MX"
      name          = var.domain
      domain_suffix = false
      content       = "smtp.google.com"
      priority      = 1
      ttl           = 300
    }
    spf = {
      type          = "TXT"
      name          = var.domain
      domain_suffix = false
      content       = "v=spf1 include:_spf.google.com ~all"
      ttl           = 300
    }
    domain_key = {
      type          = "TXT"
      name          = "google._domainkey"
      domain_suffix = false
      content       = var.domain_key
      ttl           = 300
    }
    verification = {
      type          = "TXT"
      name          = var.domain
      domain_suffix = false
      content       = "google-site-verification=${var.verification}"
      ttl           = 300
    }
  }

  providers = {
    cloudflare = cloudflare
  }
}

