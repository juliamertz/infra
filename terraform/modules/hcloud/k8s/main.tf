resource "hcloud_network" "network" {
  name     = "network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "internal" {
  network_id   = hcloud_network.network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_load_balancer" "load_balancer" {
  name               = "control-plane"
  load_balancer_type = "lb11"
  location           = var.location

  labels = {
    type = "control-plane"
  }
}

resource "hcloud_load_balancer_service" "load_balancer_service" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "tcp"

  listen_port = 6443
  destination_port = 6443
}

module "control_plane" {
  count = var.control_plane.count

  source      = "../talos_server"
  name        = "control-plane-${count.index}"
  type        = "controlplane"
  server_type = "cx22"
  config_dir = var.talos_config_dir

  load_balancer_id = hcloud_load_balancer.load_balancer.id
  network_id  = hcloud_network.network.id

  providers = {
    hcloud = hcloud
  }
}

module "worker" {
  count = var.worker.count

  source      = "../talos_server"
  name        = "worker-${count.index}"
  type        = "worker"
  server_type = "cx22"
  config_dir = var.talos_config_dir

  load_balancer_id = hcloud_load_balancer.load_balancer.id
  network_id  = hcloud_network.network.id

  providers = {
    hcloud = hcloud
  }
}
