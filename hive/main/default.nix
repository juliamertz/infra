{
  name,
  nodes,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./grafana

    ../../nixosModules/nettenshop
    ../../nixosModules/wireguard
    ../../nixosModules/cache
  ];

  networking.hostName = name;

  sops.age.keyFile = "/etc/sops/age/keys.txt";

  services.nettenshop = {
    enable = true;
    openFirewall = true;
    sopsFile = ../../secrets/nettenshop.yaml;
    extraUsers = ["julia"];
  };

  sops.secrets.wireguardPrivateKey = {
    key = name;
    owner = "julia";
    sopsFile = ../../secrets/wireguard.yaml;
  };

  services.wireguard-client = {
    enable = true;
    ipRange = "10.100.0.2/24";
    serverIp = "10.0.1.1";
    privateKeyFile = config.sops.secrets.wireguardPrivateKey.path;
  };

  networking.firewall.allowedTCPPorts = [3000];


  services.cache = {
    enable = true;
    openFirewall = true;
    sopsFile = ../../secrets/attic.env;
  };
}

