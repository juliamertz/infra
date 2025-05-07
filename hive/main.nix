{
  name,
  nodes,
  pkgs,
  config,
  ...
}: {
  networking.hostName = name;

  deployment = {
    targetHost = name;
    targetUser = "root";
    targetPort = 22;
  };

  services.nettenshop = {
    enable = true;
    openFirewall = true;
    sopsFile = ../secrets/nettenshop.yaml;
    extraUsers = ["julia"];
  };

  services.wireguard-client = {
    enable = true;
    ipRange = "10.100.0.2/24";
    serverIp = "10.0.1.1";
  };

  sops.age.keyFile = "/etc/sops/age/keys.txt";

  imports = [
    ../nixosModules/nettenshop
    ../nixosModules/wireguard
  ];
}
