terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 0.13"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4"
    }
  }
}

variable "hcloud_token" {}

variable "cloudflare_token" {}

variable "build_on_target" {
  description = "Build the NixOS configuration on the target machine"
  type        = bool
  default     = false
}
