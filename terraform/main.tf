provider "hcloud" {
  alias = "production"
  token = var.production_hcloud_token
}

provider "hcloud" {
  alias = "development"
  token = var.development_hcloud_token
}

provider "hcloud" {
  alias = "thenewnorm"
  token = var.thenewnorm_hcloud_token
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

  talos_version      = "1.12.3"
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

  extra_firewall_rules = [
    {
      description = "Allow Incoming Requests to Headscale Derp Server"
      direction   = "in"
      protocol    = "tcp"
      port        = "30478"
      source_ips  = ["0.0.0.0/0", "::/0"]
    },
  ]

  providers = {
    hcloud = hcloud.production
  }
}

module "thenewnorm_production_k8s" {
  source = "./modules/hcloud/talos_cluster"

  talos_version      = "1.12.3"
  kubernetes_version = "1.35.1"

  hcloud_token = var.thenewnorm_hcloud_token

  cluster_name     = "thenewnorm.nl"
  cluster_api_host = "kube.thenewnorm.nl"

  datacenter_name = local.datacenter

  control_plane_count          = 0
  control_plane_server_type    = "cx23"
  control_plane_allow_schedule = false

  control_plane_nodes = [
    { type = "cx23" },
    { type = "cx23" },
    { type = "cx23" },
    # { type = "cx23" },
    # { type = "cx23" },
  ]

  worker_nodes = [
    { type = "cx43" },
    { type = "cx43" },
  ]

  network_ipv4_cidr = "10.0.0.0/16"
  node_ipv4_cidr    = "10.0.1.0/24"
  pod_ipv4_cidr     = "10.0.16.0/20"
  service_ipv4_cidr = "10.0.8.0/21"

  providers = {
    hcloud = hcloud.thenewnorm
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

module "vertrouwdbouwen-resend" {
  source     = "./modules/cloudflare/resend"
  domain     = "thenewnorm.nl"
  domain_key = "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC5+/c8IPqCrLCNpgadzdNcEqONKE12s7IUHS4FVJHmlZxrhLvKgajdODREbmLmyGoXInxExEmXbeo/8HBSbPc+AvxrnZD4eua2N5zEZRwEVT+WNX11Wb7cJowyahNNX2UBYKiJRUp2JF3HX4rB0yUoZbmV/qQWPSC0mxe0j4veIwIDAQAB"

  zone_id = var.vertrouwdbouwen_com_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "thenewnorm-google-workspace" {
  source       = "./modules/cloudflare/google-workspace"
  domain       = "thenewnorm.nl"
  verification = "aOyucWyvyUROherG-GOlfnKrqBD47218NiS2FyUQx0s"
  domain_key   = "v=DKIM1;k=rsa;p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0JWgmft18wHTtL64iRZUzZW6gnXpk0UZxpBJd7F49TGH3nbrhc0V59xX/eMEPPHVDTMccroLzvKf2JzQMlCrdobkxyrC10lwDW0NBoQozCdw5yUJVPP5Dl5+Bp513M//1q5NweCsQTjjdpu59DRbPT2WbEgPd9/Ztarofd/th3OR52UM8o3XeeJkgOGRSYVYjfXaM0JF9bb0VBku8T9y225AzhzOHqrsxX2wcmm6/GdDR/XMyGlPyWttuuzisH8ohYw/gjaSppqapwVDqyhKNXDcjzSXcc/DQQr6PrEWt4qN7thQaONIJRZ0vduQVFOGrBF8LMICIscbXjlOvb8KEQIDAQAB"

  zone_id = var.vertrouwdbouwen_com_zone_id
  providers = {
    cloudflare = cloudflare
  }
}

module "thenewnorm-clerk" {
  source       = "./modules/cloudflare/clerk"
  domain       = "thenewnorm.nl"
  key = "gc5nuohb5hjl"

  zone_id = var.vertrouwdbouwen_com_zone_id
  providers = {
    cloudflare = cloudflare
  }
}
