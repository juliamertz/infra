locals {
  scripts = "${path.module}/scripts"
  out     = "${path.module}/templated"
}

resource "local_file" "nixos_infect" {
  filename = "${local.out}/nixos-infect"
  content = templatefile("${local.scripts}/nixos-infect", {
    nixos_channel = var.nixos_channel
  })
}
