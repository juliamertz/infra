{
  kubenix,
  lib,
  ...
}: let
  modules = [
    ./base/cert-manager
    ./base/cloudnative-pg
    ./base/dragonfly-operator
    ./base/envoy-gateway
    ./base/external-dns
    ./base/headscale-operator
    ./base/longhorn
    ./base/metrics-server
    # ./apps/goldilocks
    ./apps/chartmuseum
    ./apps/miniflux
    ./apps/theme-park
  ];
in {
  imports = with kubenix.modules; [submodules k8s];

  submodules.imports = modules;
  submodules.instances =
    lib.genAttrs (modules |> map baseNameOf) (name: let
    in {submodule = name;});
}
