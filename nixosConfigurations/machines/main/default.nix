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

  services.wireguard-server = {
    enable = true;
    privateKeyFile = "/etc/wireguard/keys/private";
    externalInterface = "eth0";
  };

  imports = [
    ../../modules/nettenshop
    ../../modules/wireguard
    inputs.sops.nixosModules.sops
  ];
}
