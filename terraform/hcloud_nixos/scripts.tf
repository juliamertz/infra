locals {
  scripts = "${path.module}/scripts"
  out     = "${path.module}/templated"
}

resource "local_file" "nixos_infect" {
  filename = "${local.out}/nixos-infect.sh"
  content = templatefile("${local.scripts}/nixos-infect.sh", {
    nixos_channel = var.nixos_channel
  })
}

resource "local_file" "remote_rebuild" {
  filename = "${local.out}/remote-rebuild.sh"
  content = templatefile("${local.scripts}/remote-rebuild.sh", {
    flake                 = var.flake
    experimental_features = var.experimental_features
  })
}

resource "local_file" "local_rebuild" {
  filename = "${local.out}/local-rebuild.sh"
  content  = file("${local.scripts}/local-rebuild.sh")
}
