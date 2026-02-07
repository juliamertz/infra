{
  pkgs,
  kubenix,
  ...
}: let
  inherit (pkgs) lib;
  inherit (pkgs.stdenv.hostPlatform) system;

  output = kubenix.evalModules.${system} {
    module = {kubenix, ...}: {
      imports = [
        ./manifest
      ];
    };
  };
in
  output
