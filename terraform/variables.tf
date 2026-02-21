terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 0.13"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

variable "flake_path" {
  type    = string
  default = "../"
}

variable "development_hcloud_token" {}
variable "production_hcloud_token" {}

variable "cloudflare_token" {}

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

variable "vertrouwdbouwen_com_zone_id" {
  type    = string
  default = "96716f73b11ff495e24cb213543f5d13"
}
