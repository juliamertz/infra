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

resource "local_file" "remote_rebuild" {
  filename = "${local.out}/remote-rebuild"
  content = templatefile("${local.scripts}/remote-rebuild", {
    flake                 = var.remote_flake_path
    experimental_features = var.experimental_features
  })
}

resource "local_file" "local_rebuild" {
  filename = "${local.out}/local-rebuild"
  content  = file("${local.scripts}/local-rebuild")
}
