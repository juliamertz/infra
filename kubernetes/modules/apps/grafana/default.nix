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

    ./loki.nix
    ./kube-prometheus-stack.nix
    ./blackbox-exporter.nix
    ./grafana.nix
  ];

  kubernetes = {
    namespace = "monitoring";

    resources.namespaces.monitoring.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
      "pod-security.kubernetes.io/audit" = "privileged";
      "pod-security.kubernetes.io/warn" = "privileged";
    };
  };

  submodule = {
    name = "grafana";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
