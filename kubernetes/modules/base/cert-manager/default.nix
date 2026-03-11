{
  kubenix,
  config,
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
    email = mkOption {
      type = types.str;
      default = "info@juliamertz.dev";
    };
  };

  config.kubernetes = {
    namespace = "cert-manager";

    resources.namespaces.cert-manager = {};

    resources.helmRepositories.jetstack.spec = {
      url = "https://charts.jetstack.io";
    };

    resources.helmReleases.cert-manager.spec = {
      chart.spec = {
        chart = "cert-manager";
        version = "v1.19.4";
        sourceRef = {
          kind = "HelmRepository";
          name = "jetstack";
        };
      };
      install.crds = "CreateReplace";
      upgrade.crds = "CreateReplace";
      values = {
        crds.enabled = true;
        global.leaderElection.namespace = "cert-manager";
        resources = {
          requests = {
            cpu = "50m";
            memory = "100M";
          };
          limits = {
            cpu = "50m";
            memory = "100M";
          };
        };
        cainjector.resources = {
          requests = {
            cpu = "50m";
            memory = "80M";
          };
          limits = {
            cpu = "100m";
            memory = "100M";
          };
        };
        webhook.resources = {
          requests = {
            cpu = "50m";
            memory = "50M";
          };
          limits = {
            cpu = "100m";
            memory = "100M";
          };
        };
      };
    };

    resources.clusterIssuers.letsencrypt-prod.spec = {
      acme = {
        email = config.submodule.args.email;
        preferredChain = "";
        privateKeySecretRef.name = "letsencrypt-prod";
        server = "https://acme-v02.api.letsencrypt.org/directory";
        solvers = [
          {
            dns01.cloudflare.apiTokenSecretRef = {
              name = "cloudflare-api-key";
              key = "apiKey";
            };
          }
        ];
      };
    };
  };

  config.submodule = {
    name = "cert-manager";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
