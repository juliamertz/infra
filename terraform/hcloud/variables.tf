terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}

variable "build_on_target" {
  description = "Build the NixOS configuration on the target machine"
  type        = bool
  default     = false
}

variable "flake_path" {
  type        = string
  description = "Path to directory containing your flake.nix and hive directory"
}

