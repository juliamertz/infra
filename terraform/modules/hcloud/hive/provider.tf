terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 0.13"
    }
  }
}

provider "hcloud" {
  token = var.token
}
