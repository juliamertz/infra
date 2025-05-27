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

variable "verification" {
  type = string
}
