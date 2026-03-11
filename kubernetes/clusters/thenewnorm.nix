{
  kubenix,
  util,
  crds,
  ...
}: {
  imports = with kubenix.modules; [submodules k8s];

  submodules = {
    imports = [
      ../modules/gateway
      ../modules/base/cert-manager
      ../modules/base/cloudnative-pg
      ../modules/base/dragonfly-operator
      ../modules/base/envoy-gateway
      ../modules/base/external-dns
      ../modules/base/metrics-server
      ../modules/identities.nix
    ];
    specialArgs = {inherit util crds;};
    instances = {
      envoy-gateway = {
        submodule = "envoy-gateway";
        args = {
          loadBalancer.name = "thenewnorm-lb";
          envoy = {
            replicas = 2;
            hpa.maxReplicas = 8;
          };
        };
      };

      cert-manager = {
        submodule = "cert-manager";
        args.email = "info@thenewnorm.nl";
      };

      cloudnative-pg.submodule = "cloudnative-pg";

      dragonfly-operator.submodule = "dragonfly-operator";

      external-dns = {
        submodule = "external-dns";
        args.domainFilters = [
          "vertrouwdbouwen.com"
          "thenewnorm.nl"
        ];
      };

      identities = {
        submodule = "identities";
        args = {};
      };

      metrics-server.submodule = "metrics-server";
    };
  };
}
