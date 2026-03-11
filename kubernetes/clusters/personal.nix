{
  kubenix,
  util,
  crds,
  ...
}: {
  imports = with kubenix.modules; [submodules k8s];

  submodules = {
    specialArgs = {inherit util crds;};
    imports = [
      ../modules/gateway
      ../modules/routes.nix
      ../modules/api-server.nix
      ../modules/barman.nix
      ../modules/identities.nix
      ../modules/github-registry.nix
      ../modules/base/cert-manager
      ../modules/base/cloudnative-pg
      ../modules/base/dragonfly-operator
      ../modules/base/envoy-gateway
      ../modules/base/external-dns
      ../modules/base/headscale-operator
      ../modules/base/longhorn
      ../modules/base/metrics-server
      ../modules/apps/chartmuseum
      ../modules/apps/miniflux
      ../modules/apps/theme-park
      ../modules/apps/adsb-proxy
      ../modules/apps/attic
      ../modules/apps/authelia
      ../modules/apps/garage
      ../modules/apps/grafana
      ../modules/apps/headscale
      ../modules/apps/tailscale-agent
    ];
    instances = {
      gateway.submodule = "gateway";

      routes.submodule = "routes";

      api-server.submodule = "api-server";

      barman.submodule = "barman";

      identities.submodule = "identities";

      github-registry.submodule = "github-registry";

      cert-manager.submodule = "cert-manager";

      cloudnative-pg.submodule = "cloudnative-pg";

      dragonfly-operator.submodule = "dragonfly-operator";

      envoy-gateway = {
        submodule = "envoy-gateway";
        args = {
          configure = true;
          loadBalancer.name = "envoy-gateway-shared-lb";
        };
      };

      external-dns = {
        submodule = "external-dns";
        args.domainFilters = [
          "juliamertz.dev"
          "juliamertz.nl"
          "juliamertz.com"
          "merlijnvoncken.nl"
          "merlijnvoncken.com"
          "vertrouwdbouwen.com"
          "thenewnorm.nl"
          "valnetten.nl"
        ];
      };

      headscale-operator.submodule = "headscale-operator";

      longhorn.submodule = "longhorn";

      metrics-server.submodule = "metrics-server";

      chartmuseum.submodule = "chartmuseum";

      miniflux.submodule = "miniflux";

      theme-park.submodule = "theme-park";

      adsb-proxy.submodule = "adsb-proxy";

      attic.submodule = "attic";

      authelia.submodule = "authelia";

      garage.submodule = "garage";

      grafana.submodule = "grafana";

      headscale.submodule = "headscale";

      tailscale-agent.submodule = "tailscale-agent";
    };
  };
}
