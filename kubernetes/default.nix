{
  pkgs,
  kubenix,
  ...
}: let
  inherit (pkgs) lib;
  inherit (pkgs.stdenv.hostPlatform) system;

  output = kubenix.evalModules.${system} {
    module = {...}: {
      imports = [
        ./types.nix
        ./cloudnative-pg
      ];
    };
  };
in
  output.config.kubernetes.result
