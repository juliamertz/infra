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
    name          = string
    type          = string
    content       = optional(string)
    domain_suffix = optional(bool, true)
    ttl           = optional(number)
    proxied       = optional(bool)
    priority      = optional(number)
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
  default = 300
}

variable "proxied" {
  type    = bool
  default = false
}

