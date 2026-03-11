module "records" {
  source = "../records"

  zone_id = var.zone_id
  domain  = var.domain

  records = {
    frontend-api = {
      type          = "CNAME"
      name          = "clerk"
      domain_suffix = true
      content       = "frontend-api.clerk.services"
    }
    account-portal = {
      type          = "CNAME"
      name          = "accounts"
      domain_suffix = true
      content       = "accounts.clerk.services"
    }
    clkmail = {
      type          = "CNAME"
      name          = "clkmail"
      domain_suffix = true
      content       = "mail.${var.key}.clerk.services"
    }
    domain-key-1 = {
      type          = "CNAME"
      name          = "clk._domainkey"
      domain_suffix = true
      content       = "dkim1.${var.key}.clerk.services"
    }
    domain-key-2 = {
      type          = "CNAME"
      name          = "clk2._domainkey"
      domain_suffix = true
      content       = "dkim2.${var.key}.clerk.services"
    }
  }

  providers = {
    cloudflare = cloudflare
  }
}

