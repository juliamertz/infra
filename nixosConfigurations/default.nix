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
    modules = baseModules ++ [./machines/gatekeeper];
    specialArgs = {inherit inputs system;};
  };

  main = lib.nixosSystem rec {
    system = "x86_64-linux";
    modules = baseModules ++ [./machines/main];
    specialArgs = {inherit inputs system;};
  };

  cache = lib.nixosSystem rec {
    system = "x86_64-linux";
    modules = baseModules ++ [./machines/cache];
    specialArgs = {inherit inputs system;};
  };
}
