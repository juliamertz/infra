packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = "~> 1"
    }
  }
}

variable "talos_version" {
  type    = string
  default = "v1.12.2"
}

variable "talos_customization" {
  type    = string
  // iscsi and linux-tools (required for longhorn)
  default = "613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245"
}

variable "server_location" {
  type    = string
  default = "hel1"
}

variable "amd64_server_type" {
  type    = string
  default = "cx33"
}

variable "arm64_server_type" {
  type    = string
  default = "cax21"
}

locals {
  image_base = "https://factory.talos.dev/image/${var.talos_customization}/${var.talos_version}"
  image_amd64 = "${local.image_base}/hcloud-amd64.raw.xz"
  image_arm64 = "${local.image_base}/hcloud-arm64.raw.xz"
}

source "hcloud" "talos_amd64" {
  rescue       = "linux64"
  image        = "debian-11"
  location     = "${var.server_location}"
  server_type  = "${var.amd64_server_type}"
  ssh_username = "root"

  snapshot_name = "Talos Linux ${var.talos_version} - X86"
  snapshot_labels = {
    type    = "infra",
    os      = "talos",
    version = "${var.talos_version}",
    arch    = "amd64",
  }
}

source "hcloud" "talos_arm64" {
  rescue       = "linux64"
  image        = "debian-11"
  location     = "${var.server_location}"
  server_type  = "${var.arm64_server_type}"
  ssh_username = "root"

  snapshot_name = "Talos Linux ${var.talos_version} - ARM64"
  snapshot_labels = {
    type    = "infra",
    os      = "talos",
    version = "${var.talos_version}",
    arch    = "arm64",
  }
}

build {
  sources = [
    "source.hcloud.talos_amd64",
    "source.hcloud.talos_arm64",
  ]

  provisioner "shell" {
    only   = ["source.hcloud.talos_amd64"]
    inline = [
      "apt-get install -y wget",
      "wget -O /tmp/talos.raw.xz ${local.image_amd64}",
      "xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda && sync",
    ]
  }

  provisioner "shell" {
    only   = ["source.hcloud.talos_arm64"]
    inline = [
      "apt-get install -y wget",
      "wget -O /tmp/talos.raw.xz ${local.image_arm64}",
      "xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda && sync",
    ]
  }
}
