variable "location" {
  type    = string
  default = "nbg1"
}

variable "datacenter" {
  type    = string
  default = "nbg1-dc3"
}


variable "talos_config_dir" {
  type = string
}

variable "control_plane" {
  type    = object({
    count = number
  })
}

variable "worker" {
  type    = object({
    count = number
  })
}
