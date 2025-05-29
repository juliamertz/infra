{
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

  services.nettenshop = {
    enable = true;
    sopsFile = ../../secrets/nettenshop.yaml;
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
