{
  lib,
  inputs,
  ...
}: let
  baseModules = with inputs.srvos.nixosModules; [
    server
    hardware-hetzner-cloud
    mixins-terminfo
    ./base.nix
  ];
in {
  gatekeeper = lib.nixosSystem rec {
    system = "x86_64-linux";
    modules = baseModules ++ [./gatekeeper];
    specialArgs = {inherit inputs system;};
  };

  main = lib.nixosSystem rec {
    system = "x86_64-linux";
    modules = baseModules ++ [./main];
    specialArgs = {inherit inputs system;};
  };
}
