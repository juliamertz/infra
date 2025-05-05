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
    sopsFile = ../../secrets/nettenshop.yaml;
  };

  users.users.julia.extraGroups = [config.services.nettenshop.group];

  imports = [
    ./services/nettenshop.nix
    ../modules/wireguard/server.nix
    inputs.sops.nixosModules.sops
  ];
}
