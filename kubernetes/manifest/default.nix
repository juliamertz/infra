{
  kubenix,
  lib,
  util,
  crds,
  ...
}: let
  modules = [
    ./gateway
    ./routes.nix
    ./api-server.nix
    ./barman.nix
    ./identities.nix
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
    ./apps/adsb-proxy
    ./apps/attic
    ./apps/authelia
    ./apps/garage
    ./apps/grafana
    ./apps/headscale
    ./apps/tailscale-agent
    # ./apps/valheim-server
  ];
in {
  imports = with kubenix.modules; [submodules k8s];

  submodules = {
    imports = modules;
    specialArgs = {inherit util crds;};
    instances =
      lib.genAttrs (modules |> map baseNameOf |> map (lib.removeSuffix ".nix")) (name: let
      in {submodule = name;});
  };
}
