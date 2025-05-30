{
  inputs,
  name,
  nodes,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./monitoring

    ../../nixosModules/nettenshop
    ../../nixosModules/wireguard
    ../../nixosModules/cache
  ];

  networking.hostName = name;

  sops.age.keyFile = "/etc/sops/age/keys.txt";

  fileSystems. "/data" = {
    device = "/dev/sdb";
    fsType = "ext4";
    options = ["data=journal"];
  };

  services.nettenshop = {
    enable = true;
    package = inputs.lightspeed-dhl-adapter.packages.${pkgs.system}.default;
    sopsFile = ../../secrets/nettenshop.yaml;
    stateDir = "/data/lightspeed-dhl";
    extraUsers = ["julia"];
  };

  sops.secrets.wireguardPrivateKey = {
    key = name;
    owner = "julia";
    sopsFile = ../../secrets/wireguard.yaml;
  };

  services.wireguard-client = let
    inherit (config.services.wireguard-client) net;
  in {
    enable = true;
    ipRange = "${net.peers.${name}.subnetIp}/23";
    serverIp = "10.0.1.1";
    privateKeyFile = config.sops.secrets.wireguardPrivateKey.path;
  };

  services.cache = {
    enable = true;
    sopsFile = ../../secrets/attic.env;
  };
}
