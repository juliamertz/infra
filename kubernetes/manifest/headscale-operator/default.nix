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
    namespace = "headscale-operator";

    resources.namespaces.headscale-operator = {};

    resources.helmRepositories.headscale-operator.spec = {
      interval = "5m";
      url = "https://charts.juliamertz.dev";
    };

    resources.helmReleases.headscale-operator.spec = {
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

  config.submodule = {
    name = "headscale-operator";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
