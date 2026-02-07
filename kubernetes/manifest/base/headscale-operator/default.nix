{
  config,
  kubenix,
  crds,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = {
    namespace = "headscale-operator";

    resources.namespaces.headscale-operator = {};

    resources.helmRepositories.headscale-operator.spec = {
      url = "https://charts.juliamertz.dev";
    };

    resources.helmReleases.headscale-operator.spec = {
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

  submodule = {
    name = "headscale-operator";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
