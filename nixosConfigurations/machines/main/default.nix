{
  inputs,
  config,
  ...
}: {
  networking.hostName = "main";

  sops.age.keyFile = "/etc/sops/age/keys.txt";

  services.nettenshop = {
    enable = true;
    openFirewall = true;
    sopsFile = ../../../secrets/nettenshop.yaml;
    extraUsers = ["julia"];
  };

  services.wireguard-client = {
    enable = true;
    ipRange = "10.100.0.2/24";
    serverIp = "10.0.1.1"; 
  };

  imports = [
    ../../modules/nettenshop
    ../../modules/wireguard
    inputs.sops.nixosModules.sops
  ];
}
