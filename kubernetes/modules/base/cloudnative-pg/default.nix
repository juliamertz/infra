{
  config,
  kubenix,
  util,
  crds,
  pkgs,
  lib,
  ...
}: {
  imports = [
    kubenix.modules.submodule
    kubenix.modules.k8s
    crds
  ];

  kubernetes = {
    namespace = "cnpg-system";

    objects = let
      version = "1.28.1";
      manifests =
        (util.fetchYAML {
          url = "https://github.com/cloudnative-pg/cloudnative-pg/releases/download/v${version}/cnpg-${version}.yaml";
          sha256 = "sha256-JeDDPCNK7zt8PgXJlZsYOj3/MYca1StwPXZvCk9Ab5I=";
        })
        ++ util.fetchYAML {
          url = "https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/v0.5.0/manifest.yaml";
          sha256 = "sha256-26wmaBHU+CSyLDFToFaoUoNZV68+X3Y90q0woB5Q+v8=";
        };
    in
      manifests |> builtins.filter util.isCrd;

    resources.namespaces.cnpg-system.metadata.labels = {
      "vector.dev/exclude" = "true";
    };

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

  submodule = {
    name = "cloudnative-pg";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
