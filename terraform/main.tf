provider "hcloud" {
  alias = "production"
  token = var.production_hcloud_token
}

provider "hcloud" {
  alias = "development"
  token = var.development_hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

locals {
  location   = "nbg1"
  datacenter = "nbg1-dc3"
}

module "production_k8s" {
  source = "./modules/hcloud/talos_cluster"

  talos_version      = "1.11.1"
  kubernetes_version = "1.34.1"

  hcloud_token = var.production_hcloud_token

  cluster_name     = "juliamertz.dev"
  cluster_api_host = "kube.juliamertz.dev"

  datacenter_name = local.datacenter

  control_plane_count          = 0
  control_plane_server_type    = "cax11"
  control_plane_allow_schedule = true

  control_plane_nodes = [
    { type = "cx33" },
    { type = "cx33" },
    { type = "cx33" },
  ]

  worker_nodes = [
    # { type = "cx43" },
    # { type = "cx33" },
  ]

  network_ipv4_cidr = "10.0.0.0/16"
  node_ipv4_cidr    = "10.0.1.0/24"
  pod_ipv4_cidr     = "10.0.16.0/20"
  service_ipv4_cidr = "10.0.8.0/21"

  providers = {
    hcloud = hcloud.production
  }
}

resource "cloudflare_dns_record" "records" {
  for_each = module.production_k8s.loadbalancer_target_ips

  zone_id = var.juliamertz_nl_zone_id
  name    = "headscale"
  type    = "A"
  content = each.value
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "api_server_records" {
  for_each = module.production_k8s.control_plane_ips

  zone_id = var.juliamertz_dev_zone_id
  name    = "kube"
  type    = "A"
  content = each.value
  ttl     = 1
  proxied = false
}

module "juliamertz-nl-email" {
  source       = "./modules/cloudflare/protonmail"
  domain       = "juliamertz.nl"
  domain_key   = "dbq6tjrv6pl3rnk666437sono7h6tufi6fwst37wbkcurzjsldlwq"
  verification = "3de7592f07cd8507ec05b83e5403f4a35c3dc5d9"

  zone_id = var.juliamertz_nl_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-dev-email" {
  source       = "./modules/cloudflare/protonmail"
  domain       = "juliamertz.dev"
  domain_key   = "dioxqwztivzonpgfbsqunytokvr2xiy4fn2qrdz54llx3c2bvrrkq"
  verification = "25429d3b39ef4a4a68b4933efa8911c8b830c71a"

  zone_id = var.juliamertz_dev_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

# resource "hcloud_ssh_key" "julia" {
#   name       = "ssh-key-julia"
#   public_key = file("~/.ssh/id_ed25519.pub")
# }

# module "nixos_bastion" {
#   source      = "./modules/hcloud/nixos_server"
#   name        = "bastion"
#   server_type = "cx23"
#   datacenter  = "nbg1-dc3"
#
#   network_id  = module.production_k8s.hetzner_network_id
#
#   internal_ip = "10.0.1.1"
#   public_ip   = true
#
#   nixos_channel   = "nixos-unstable"
#   flake_path      = ".."
#   flake_profile   = "bastion"
#   build_on_target = true
#
#   ssh_keys        = [hcloud_ssh_key.julia.id]
#   ssh_private_key = file("~/.ssh/id_ed25519")
#   sops_age_key    = "~/.config/sops/age/keys.txt"
#
#   providers = {
#     hcloud = hcloud.production
#   }
# }

