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
    ./volumes.nix
    ./wireguard.nix

    ../../nixosModules/nettenshop
    ../../nixosModules/cache
  ];

  services.nettenshop = {
    enable = true;
    package = inputs.lightspeed-dhl-adapter.packages.${pkgs.system}.default;
    sopsFile = ../../secrets/nettenshop.yaml;
    stateDir = "/data/lightspeed-dhl";
    extraUsers = ["julia"];
  };

  services.cache = {
    enable = true;
    sopsFile = ../../secrets/attic.env;
  };
}
