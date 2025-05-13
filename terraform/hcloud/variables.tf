terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}

variable "local_build" {
  type        = bool
  default     = false
  description = "Whether to build the NixOS configurations on your local machine or remotely"
}

variable "flake_path" {
  type        = string
  description = "Path to directory containing your flake.nix and hive directory"
}

