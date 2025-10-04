locals {
  rules = [
    {
      description = "Allow Incoming Requests to Kube API Server"
      direction   = "in"
      protocol    = "tcp"
      port        = "6443"
      source_ips = [ "0.0.0.0/0", "::/0" ]
    },
    {
      description = "Allow Incoming Requests to Talos API Server"
      direction   = "in"
      protocol    = "tcp"
      port        = "50000"
      source_ips = [ "0.0.0.0/0", "::/0" ]
    },
    {
      description = "Allow Incoming Requests to Headscale API Server"
      direction   = "in"
      protocol    = "tcp"
      port        = "30443"
      source_ips = [ "0.0.0.0/0", "::/0" ]
    },
    {
      description = "Allow Incoming Requests to Headscale Derp Server"
      direction   = "in"
      protocol    = "tcp"
      port        = "30478"
      source_ips = [ "0.0.0.0/0", "::/0" ]
    },
  ]
}

resource "hcloud_firewall" "firewall" {
  name = var.cluster_name

  dynamic "rule" {
    for_each = local.rules

    content {
      description     = rule.value.description
      direction       = rule.value.direction
      protocol        = rule.value.protocol
      port            = lookup(rule.value, "port", null)
      destination_ips = lookup(rule.value, "destination_ips", [])
      source_ips      = lookup(rule.value, "source_ips", [])
    }
  }
  labels = {
    "cluster" = var.cluster_name
  }
}
