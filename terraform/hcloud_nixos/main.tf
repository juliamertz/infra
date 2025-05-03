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
    ipv4_enabled = var.public_ip
    ipv6_enabled = var.public_ip
  }

  connection {
    type        = "ssh"
    host        = hcloud_server.server.ipv4_address
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    on_failure = continue
    script     = local_file.nixos_infect.filename
  }

  provisioner "local-exec" {
    command = "echo Waiting for NixOS to boot... && sleep 10"
  }
}

resource "null_resource" "install_age_key" {
  count = var.sops_age_key != null ? 1 : 0

  connection {
    type        = "ssh"
    host        = hcloud_server.server.ipv4_address
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/sops/age",
      "cat > /etc/sops/age/keys.txt <<EOF\n${var.sops_age_key}\nEOF",
      "chmod 600 /etc/sops/age/keys.txt"
    ]
  }
}

resource "null_resource" "remote_rebuild" {
  count = var.local_build ? 0 : 1

  connection {
    type        = "ssh"
    host        = hcloud_server.server.ipv4_address
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    script = local_file.remote_rebuild.filename
  }
}

resource "null_resource" "local_rebuild" {
  count = var.local_build ? 1 : 0
  provisioner "local-exec" {
    command = local_file.local_rebuild.content
    environment = {
      FLAKE       = var.flake
      SSH_USER    = var.ssh_user
      SSH_ADDRESS = hcloud_server.server.ipv4_address
    }
  }
}
