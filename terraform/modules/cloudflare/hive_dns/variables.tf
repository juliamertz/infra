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

variable "name" {
  type = string
}

variable "ip" {
  type = string
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
