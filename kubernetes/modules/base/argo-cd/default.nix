{
  kubenix,
  config,
  crds,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = {
    namespace = "argo-cd";

    resources.namespaces.argo-cd = {};

    resources.helmRepositories.argo.spec = {
      url = "https://argoproj.github.io/argo-helm";
    };

    resources.helmReleases.argo-cd.spec = {
      chart.spec = {
        chart = "argo-cd";
        version = "9.4.1";
        sourceRef = {
          kind = "HelmRepository";
          name = "argo";
        };
      };
      install.crds = "CreateReplace";
      upgrade.crds = "CreateReplace";
      values = {
        crds.install = true;
      };
    };
  };

  submodule = {
    name = "argo-cd";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
