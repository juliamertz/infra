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

    resources.namespaces.headscale-operator.metadata.labels = {
      "vector.dev/exclude" = "true";
    };

    resources.helmRepositories.headscale-operator.spec = {
      url = "https://charts.juliamertz.dev";
    };

    resources.helmReleases.headscale-operator.spec = {
      chart.spec = {
        chart = "headscale-operator";
        version = "v0.0.4";
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
