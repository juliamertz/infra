data "hcloud_image" "packer_snapshot" {
  with_selector = "os=talos,version=${var.talos_version}"
  most_recent = true
}

resource "hcloud_server" "server" {
  name        = var.name
  image = data.hcloud_image.packer_snapshot.id

  user_data = file("${var.config_dir}/${var.type}.yaml")

  server_type = var.server_type
  datacenter  = var.datacenter

  network { network_id = var.network_id }

  labels = {
    type = var.type
  }
}

resource "hcloud_load_balancer_target" "load_balancer_target" {
  count = var.type == "controlplane" ? 1 : 0

  type             = "server"
  load_balancer_id = var.load_balancer_id
  server_id        = hcloud_server.server.id
}
