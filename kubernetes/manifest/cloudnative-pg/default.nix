{
  config,
  lib,
  pkgs,
  kubenix,
  ...
}: {
  imports = with kubenix.modules; [
    submodules
    k8s
    ../../type
  ];

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
}
