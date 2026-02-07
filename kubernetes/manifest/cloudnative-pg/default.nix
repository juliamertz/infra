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
    namespace = "cnpg-system";

    resources.namespaces.cnpg-system = {};

    resources.helmRepositories.cloudnative-pg.spec = {
      url = "https://cloudnative-pg.github.io/charts";
    };

    resources.helmReleases.cloudnative-pg.spec = {
      chart.spec = {
        chart = "cloudnative-pg";
        version = "0.27.1";
        sourceRef = {
          kind = "HelmRepository";
          name = "cloudnative-pg";
        };
      };
      values = {
        crds.create = false;
      };
    };

    resources.helmReleases.barman-plugin.spec = {
      chart.spec = {
        chart = "plugin-barman-cloud";
        version = "0.5.0";
        sourceRef = {
          kind = "HelmRepository";
          name = "cloudnative-pg";
        };
      };
      values = {
        fullnameOverride = "barman-cloud-plugin";
        crds.create = false;
      };
    };
  };

  config.submodule = {
    name = "cloudnative-pg";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
