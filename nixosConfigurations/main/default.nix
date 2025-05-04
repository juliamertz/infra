{
  inputs,
  config,
  ...
}:{
  networking = {
    hostName = "main";

    interfaces.enp7s0.useDHCP = true;
    firewall = {
      trustedInterfaces = ["enp7s0"];
    };
  };

  sops.age.keyFile = "/etc/sops/age/keys.txt";

  services.nettenshop = {
    enable = true;
    openFirewall = true;
  };
  users.users.julia.extraGroups = [config.services.nettenshop.group];

  imports = [
    ./services/nettenshop.nix
    inputs.sops.nixosModules.sops
  ];
}
