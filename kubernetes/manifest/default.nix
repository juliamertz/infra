{
  kubenix,
  lib,
  ...
}: let
  modules = [
    ./cert-manager
    ./cloudnative-pg
    ./dragonfly-operator
    ./envoy-gateway
    ./external-dns
    ./headscale-operator
    ./longhorn
    ./metrics-server
  ];
in {
  imports = with kubenix.modules; [submodules k8s];

  submodules.imports = modules;
  submodules.instances =
    lib.genAttrs (modules |> map baseNameOf) (name: let
    in {submodule = name;});
}
