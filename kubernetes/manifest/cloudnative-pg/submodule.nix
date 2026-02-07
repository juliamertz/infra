{
  config,
  kubenix,
  lib,
  name,
  args,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
  ];

  config = {
    imports = [../../type];

    submodule = {
      name = "cloudnative-pg";

      passthru.kubernetes.objects = config.kubernetes.objects;
    };

    kubernetes = {
      namespace = "cnpg-system";

      resources.namespaces.cnpg-system = {};

      resources.helmrepositories.cloudnative-pg.spec = {
        url = "https://cloudnative-pg.github.io/charts";
      };

      resources.helmreleases.cloudnative-pg.spec = {
        interval = "30m";
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

      resources.helmreleases.barman-plugin.spec = {
        interval = "30m";
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
  };
}
