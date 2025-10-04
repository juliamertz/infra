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

data "external" "host" {
  program = [
    "nix",
    "eval",
    "--impure",
    "--raw",
    "--expr",
    "builtins.toJSON { system = builtins.currentSystem; }",
  ]
}

locals {
  location        = "nbg1"
  datacenter      = "nbg1-dc3"
  nixos_channel   = "nixos-unstable"
  build_on_target = data.external.host.result.system != "x86_64-linux"

  ssh_private_key = "~/.ssh/id_ed25519"
  ssh_public_key  = "~/.ssh/id_ed25519.pub"
  sops_age_key    = "~/.config/sops/age/keys.txt"

  records = {
    root    = { type = "A", name = "@" }
    www     = { type = "A", name = "www" }
    grafana = { type = "A", name = "grafana" }
    gh      = { type = "A", name = "gh" }
    wg      = { type = "A", name = "wg", proxied = false }
    hass       = { type = "A", name = "hass" }
    watch      = { type = "A", name = "watch" }
    cache      = { type = "A", name = "cache" }
    # home-assistant  = { type = "A", name = "home-assistant" }
    # nettenshop = { type = "A", name = "nettenshop" }
    # lb_prod = { type = "A", name = "lb.prod", content = module.production_k8s.load_balancer_ipv4 }
    # mc              = { type = "A", name = "mc", content = "91.99.138.181" }
    # dynmap              = { type = "A", name = "dynmap" }
  }
}

module "production" {
  source = "./modules/hcloud/hive"

  build_on_target        = local.build_on_target
  sops_age_key           = local.sops_age_key
  deployment_private_key = "~/.ssh/id_ed25519"
  deployment_public_key  = "~/.ssh/id_ed25519.pub"
  flake_path             = var.flake_path

  providers = {
    hcloud = hcloud.production
  }
}

module "production_k8s" {
  source  = "./modules/hcloud/talos_cluster"

  talos_version      = "1.11.1"
  kubernetes_version = "1.34.1"
  cilium_version     = "1.17.8"

  hcloud_token = var.production_hcloud_token

  cluster_name     = "juliamertz.dev"
  cluster_api_host = "kube.juliamertz.dev"

  datacenter_name = local.datacenter

  control_plane_count       = 3
  control_plane_server_type = "cax11"
  control_plane_allow_schedule = false

  worker_nodes = [
    {
      type  = "cax21"
      labels = {
        "node.kubernetes.io/instance-type" = "cax21"
        "node.kubernetes.io/arch"          = "arm64"
      }
    },
    {
      type  = "cax21"
      labels = {
        "node.kubernetes.io/instance-type" = "cax21"
        "node.kubernetes.io/arch"          = "arm64"
      }
    },
  ]

  network_ipv4_cidr = "10.0.0.0/16"
  node_ipv4_cidr    = "10.0.1.0/24"
  pod_ipv4_cidr     = "10.0.16.0/20"
  service_ipv4_cidr = "10.0.8.0/21"

  providers = {
    hcloud = hcloud.production
  }
}

module "juliamertz-nl-dns" {
  source = "./modules/cloudflare/records"

  proxied         = true
  ttl             = 1
  zone_id         = var.juliamertz_nl_zone_id
  domain          = "juliamertz.nl"
  default_content = module.production.gatekeeper.ip

  records = local.records

  providers = {
    cloudflare = cloudflare
  }
}


resource "cloudflare_dns_record" "records" {
  for_each = module.production_k8s.talos_worker_ips

  zone_id  = var.juliamertz_nl_zone_id
  name = "headscale"
  type     = "A"
  content = each.value
  ttl     = 1
  proxied = false
}

module "juliamertz-dev-dns" {
  source = "./modules/cloudflare/records"

  proxied         = true
  ttl             = 1
  zone_id         = var.juliamertz_dev_zone_id
  domain          = "juliamertz.dev"
  default_content = module.production.gatekeeper.ip

  records = local.records

  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-nl-email" {
  source       = "./modules/cloudflare/protonmail"
  domain       = "juliamertz.nl"
  domain_key   = "d3u5rtsm5vj2kjzwcua5sns57x4p62m3wlapug7zjtnpps2x4ayoa"
  verification = "6d592d6c4efb07524737a4674938e729df1a629b"

  zone_id = var.juliamertz_nl_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "juliamertz-dev-email" {
  source       = "./modules/cloudflare/protonmail"
  domain       = "juliamertz.dev"
  domain_key   = "dhrcj3l7ljct2xxjwqsdgg5s2ntzdyh2nmuqinz6mgddj2godaa2a"
  verification = "9814917e48e94c4bf2e1a70e25a21b68d4d1e5f5"

  zone_id = var.juliamertz_dev_zone_id
  providers = {
    cloudflare = cloudflare
  }
}
