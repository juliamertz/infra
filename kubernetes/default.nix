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
        ./cert-manager
        ./cloudnative-pg
        ./dragonfly-operator
        ./envoy-gateway
        ./external-dns
        ./headscale-operator
        ./longhorn
        ./metrics-server
      ];
    };
  };
in
  output
