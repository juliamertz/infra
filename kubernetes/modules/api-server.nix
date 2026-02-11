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
    namespace = "kube-system";

    resources.services.api-server.spec = {
      type = "ClusterIP";
      selector = {
        "app.kubernetes.io/component" = "control-plane";
        "app.kubernetes.io/name" = "kube-apiserver";
      };
      ports = [
        {
          name = "api";
          port = 6443;
          targetPort = 6443;
          protocol = "TCP";
        }
      ];
    };
  };

  submodule = {
    name = "api-server";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
