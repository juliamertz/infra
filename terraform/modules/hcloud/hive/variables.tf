variable "location" {
  type    = string
  default = "nbg1"
}

variable "datacenter" {
  type    = string
  default = "nbg1-dc3"
}

variable "nixos_channel" {
  type    = string
  default = "nixos-unstable"
}

variable "build_on_target" {
  type    = bool
  default = true
}

variable "deployment_private_key" {
  type        = string
  description = "Path to SSH key used for deployment with colmena"
  default     = "~/.ssh/id_ed25519"
}

variable "deployment_public_key" {
  type        = string
  description = "Path to SSH key used for deployment with colmena"
  default     = "~/.ssh/id_ed25519.pub"
}

variable "sops_age_key" {
  type        = string
  description = "Path to SSH key used for deployment with colmena"
  default     = "~/.config/sops/age/keys.txt"
}

variable "flake_path" {
  description = "path to flake"
  type        = string
  default     = null
}
