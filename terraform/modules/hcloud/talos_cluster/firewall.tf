locals {
  loadbalancer_rules = [
    {
      description = "Allow Incoming Requests to Kube API Server"
      direction   = "in"
      protocol    = "tcp"
      port        = "6443"
      source_ips  = [var.firewall_allowed_ip]
    },
    {
      description = "Allow Incoming Requests to Talos API Server"
      direction   = "in"
      protocol    = "tcp"
      port        = "50000"
      source_ips  = [var.firewall_allowed_ip]
    },
    {
      description = "Allow Incoming Requests to Headscale API Server"
      direction   = "in"
      protocol    = "tcp"
      port        = "30443"
      source_ips  = ["0.0.0.0/0", "::/0"]
    },
    {
      description = "Allow Incoming Requests to Headscale Derp Server"
      direction   = "in"
      protocol    = "tcp"
      port        = "30478"
      source_ips  = ["0.0.0.0/0", "::/0"]
    },
  ]

  valheim_rules = [
    {
      description = "Allow Incoming Requests to Valheim server"
      direction   = "in"
      protocol    = "udp"
      port        = "2456"
      source_ips  = ["0.0.0.0/0", "::/0"]
    },
    {
      description = "Allow Incoming Requests to Steam query port"
      direction   = "in"
      protocol    = "udp"
      port        = "2457"
      source_ips  = ["0.0.0.0/0", "::/0"]
    },
  ]
}

resource "hcloud_firewall" "firewall" {
  name = var.cluster_name

  dynamic "rule" {
    for_each = local.loadbalancer_rules

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

resource "hcloud_firewall" "valheim_firewall" {
  name = "allow-incoming-valheim-traffic"

  dynamic "rule" {
    for_each = local.valheim_rules

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
