terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

variable "cloudflare_account_id" {
  type    = string
  default = "2b3473f287c2ddf45a7105b22e69c7a9"
}

variable "juliamertz_dev_zone_id" {
  type    = string
  default = "e449c68d1df84fc7e9791540989c3304"
}

variable "juliamertz_nl_zone_id" {
  type    = string
  default = "6848c25638c792b4251cc08c91676137"
}


variable "ip_main" {
  type = string
}

variable "ip_gatekeeper" {
  type = string
}

