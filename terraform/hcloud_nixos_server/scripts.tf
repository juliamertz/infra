locals {
  scripts_path = "${path.module}/scripts"
}

resource "local_file" "nixos_infect" {
  filename = "nixos-infect.sh"
  content = templatefile("${local.scripts_path}/nixos-infect.sh", {
    nixos_channel = "nixos-unstable"
  })
}

resource "local_file" "remote_rebuild" {
  filename = "remote-rebuild.sh"
  content = templatefile("${local.scripts_path}/remote-rebuild.sh", {
    flake = var.flake
    extra_experimental_features = var.extra_experimental_features
  })
}

resource "local_file" "local_rebuild" {
  filename = "local-rebuild.sh"
  content = file("${local.scripts_path}/local-rebuild.sh")
}
