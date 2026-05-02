{
  config,
  kubenix,
  crds,
  lib,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  options.submodule.args = with lib; {
    domainFilters = mkOption {
      type = types.listOf types.str;
      default = [];
    };
  };

  config.kubernetes = {
    namespace = "external-dns";

    resources.namespaces.external-dns.metadata.labels = {
      "vector.dev/exclude" = "true";
    };

    resources.helmRepositories.external-dns.spec = {
      url = "https://kubernetes-sigs.github.io/external-dns/";
    };

    resources.helmReleases.external-dns.spec = {
      chart.spec = {
        chart = "external-dns";
        version = "1.21.1";
        sourceRef = {
          kind = "HelmRepository";
          name = "external-dns";
        };
      };
      values = {
        policy = "sync";
        extraArgs = [
          "--exclude-target-net=10.0.0.0/16"
          "--exclude-record-types=AAAA"
        ];
        domainFilters = config.submodule.args.domainFilters;
        sources = [
          "crd"
          "service"
          "gateway-httproute"
          "gateway-grpcroute"
          "gateway-tcproute"
          "gateway-tlsroute"
          "gateway-udproute"
        ];
        provider.name = "cloudflare";
        env = [
          {
            name = "CF_API_TOKEN";
            valueFrom.secretKeyRef = {
              name = "cloudflare-api-key";
              key = "apiKey";
            };
          }
        ];
      };
    };
  };

  config.submodule = {
    name = "external-dns";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
