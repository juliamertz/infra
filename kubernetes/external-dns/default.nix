{
  config,
  lib,
  pkgs,
  kubenix,
  ...
}: {
  imports = with kubenix.modules; [submodules k8s];

  kubernetes = {
    namespace = "external-dns";

    resources.namespaces.external-dns = {};

    resources.helmrepositories.external-dns.spec = {
      url = "https://kubernetes-sigs.github.io/external-dns/";
    };

    resources.helmreleases.external-dns.spec = {
      interval = "5m";
      chart.spec = {
        chart = "external-dns";
        version = "1.19.0";
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
}
