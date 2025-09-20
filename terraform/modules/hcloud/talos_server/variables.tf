terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}

variable "name" {
  description = "Name of the server"
  type        = string
}

variable "load_balancer_id" {
  type        = number
}

variable "talos_version" {
  type    = string
  default = "v1.11.0"
}

variable "type" {
  description = "Node kind one of: [controlplane, worker]"
  type = string
}


variable "config_dir" {
  description = "Path to directory containing generated talos config"
  type = string
}

variable "server_type" {
  description = "Type/size of the server"
  type        = string
  default     = "cx22" # Smallest instance type
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
