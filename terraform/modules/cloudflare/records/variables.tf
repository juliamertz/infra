terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

variable "records" {
  description = "Map of DNS records"
  type = map(object({
    name     = string
    type     = string
    content  = optional(string)
    # suffix the 'name' field with the domain to avoid cloudflare record updates on each apply
    domain_suffix = optional(bool, true)
    ttl      = optional(number)
    proxied  = optional(bool)
    priority = optional(number)
  }))
}

variable "zone_id" {
  type = string
}

variable "default_content" {
  type    = string
  default = null
}

variable "domain" {
  type = string
}

variable "ttl" {
  type    = number
  default = 3600
}

variable "proxied" {
  type    = bool
  default = false
}

