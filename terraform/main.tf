provider "hcloud" {
  token = var.hcloud_token
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

module "hetzner_hive" {
  source          = "./hcloud"
  build_on_target = data.external.host.result.system != "x86_64-linux"
  flake_path      = "../"

  providers = {
    hcloud = hcloud
  }
}

module "cloudflare_dns" {
  source        = "./cloudflare"
  ip_gatekeeper = module.hetzner_hive.gatekeeper.ip
  ip_main       = module.hetzner_hive.main.ip

  providers = {
    cloudflare = cloudflare
  }
}
