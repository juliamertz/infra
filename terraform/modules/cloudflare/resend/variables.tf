terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

variable "zone_id" {
  type = string
}

variable "domain" {
  type = string
}

variable "domain_key" {
  type = string
}

variable "smtp_url" {
  type = string
  default = "feedback-smtp.eu-west-1.amazonses.com"
}

variable "spf" {
  type = string
  default = "v=spf1 include:amazonses.com ~all"
}

variable "dmarc" {
  type = string
  default = "v=DMARC1; p=none;"
}

