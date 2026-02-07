#   imports = with kubenix.modules; [submodules];
#
#   # submodules.imports = [
#   #   # ./cert-manager
#   #   ./cloudnative-pg
#   #   ./dragonfly-operator
#   #   # ./envoy-gateway
#   #   # ./external-dns
#   #   # ./headscale-operator
#   #   # ./longhorn
#   #   # ./metrics-server
#   # ];
# }
{
  config,
  lib,
  pkgs,
  kubenix,
  ...
}: let
  importModule = path: import path {inherit kubenix lib pkgs config;};
in {
  imports = with kubenix.modules; [submodules k8s];

  submodules.imports = [
    ./cloudnative-pg/submodule.nix
  ];

  submodules.instances.cloudnative-pg = {
    submodule = "cloudnative-pg";
    args = {};
  };
}
