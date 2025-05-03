provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_server" "server" {
  name        = var.name
  image       = var.base_image
  server_type = var.server_type
  datacenter  = var.datacenter
  ssh_keys    = var.ssh_keys

  network {
    network_id = var.network_id
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = hcloud_server.server.ipv4_address
    timeout     = var.ssh_timeout
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    on_failure = continue
    script     = local_file.nixos_infect.filename
  }

  provisioner "local-exec" {
    command = "echo Waiting for NixOS to boot... && sleep 10"
  }

  provisioner "remote-exec" {
    script = local_file.remote_rebuild.filename
  }
}

# resource "null_resource" "remote_deploy" {
#   provisioner "local-exec" {
#     command = local_file.local_rebuild.content
#     environment = {
#       FLAKE = var.flake
#       SSH_USER = var.ssh_user
#       SSH_ADDRESS = hcloud_server.server.ipv4_address
#     }
#   }
# }
