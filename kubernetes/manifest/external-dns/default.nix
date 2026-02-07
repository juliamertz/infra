{
  config,
  kubenix,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    ../../type/fluxcd.nix
  ];

  config.kubernetes = {
    namespace = "external-dns";

    resources.namespaces.external-dns = {};

    resources.helmRepositories.external-dns.spec = {
      url = "https://kubernetes-sigs.github.io/external-dns/";
    };

    resources.helmReleases.external-dns.spec = {
      interval = "5m";
      chart.spec = {
        chart = "external-dns";
        version = "1.20.0";
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
        domainFilters = [
          "juliamertz.dev"
          "juliamertz.nl"
          "juliamertz.com"
          "merlijnvoncken.nl"
          "merlijnvoncken.com"
          "vertrouwdbouwen.com"
          "valnetten.nl"
        ];
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
