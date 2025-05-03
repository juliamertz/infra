variable "name" {
  description = "Name of the server"
  type        = string
}

variable "base_image" {
  description = "Server image to use"
  type        = string
  default     = "ubuntu-20.04"
}

variable "server_type" {
  description = "Type/size of the server"
  type        = string
  default     = "cx11"  # Smallest instance type
}

variable "datacenter" {
  description = "Datacenter"
  type        = string
  default     = "nbg1-dc3"
}

variable "network_id" {
  description = "Server location/datacenter"
  type        = string
  default     = null
}

variable "ssh_keys" {
  description = "List of SSH key IDs to add to the server"
  type        = list(string)
}

variable "ssh_user" {
  description = "Username for SSH connection"
  type        = string
  default     = "root"
}

variable "ssh_timeout" {
  description = "Timeout for SSH connections"
  type        = string
  default     = "5m"
}

variable "ssh_private_key" {
  description = "private SSH key file"
  type        = string
}

variable "nixos_channel" {
  description = "NixOS channel to use"
  type        = string
  default     = "nixos-24.11"
}

variable "flake" {
  description = "link to flake the machine should bould"
  type        = string
  default     = null
}

variable "extra_experimental_features" {
  description = ""
  type = string
  default = "nix-command flakes pipe-operators"
}
