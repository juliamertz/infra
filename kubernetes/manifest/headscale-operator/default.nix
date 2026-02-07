{
  config,
  lib,
  pkgs,
  kubenix,
  ...
}: {
  imports = with kubenix.modules; [submodules k8s];

  kubernetes = {
    namespace = "headscale-operator";

    resources.namespaces.headscale-operator = {};

    resources.helmrepositories.headscale-operator.spec = {
      interval = "5m";
      url = "https://charts.juliamertz.dev";
    };

    resources.helmreleases.headscale-operator.spec = {
      interval = "5m";
      chart.spec = {
        chart = "headscale-operator";
        version = "v0.0.3";
        sourceRef = {
          kind = "HelmRepository";
          name = "headscale-operator";
        };
      };
      values = {
        crds.install = false;
      };
    };
  };
}
