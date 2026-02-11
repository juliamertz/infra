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

    resources.helmRepositories.metrics-server.spec = {
      url = "https://kubernetes-sigs.github.io/metrics-server/";
    };

    resources.helmReleases.metrics-server.spec = {
      chart.spec = {
        chart = "metrics-server";
        version = "3.13.0";
        sourceRef = {
          kind = "HelmRepository";
          name = "metrics-server";
        };
      };
      values = {
        replicas = 2;
        args = [
          "--kubelet-insecure-tls"
          "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"
          "--metric-resolution=15s"
        ];

        priorityClassName = "system-cluster-critical";

        tolerations = [
          {
            key = "node-role.kubernetes.io/control-plane";
            operator = "Exists";
            effect = "NoSchedule";
          }
        ];

        affinity = {
          nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100;
              preference.matchExpressions = [
                {
                  key = "node-role.kubernetes.io/control-plane";
                  operator = "Exists";
                }
              ];
            }
          ];
          podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 90;
              podAffinityTerm = {
                topologyKey = "kubernetes.io/hostname";
                labelSelector.matchLabels = {
                  "app.kubernetes.io/name" = "metrics-server";
                };
              };
            }
          ];
        };
      };
    };
  };

  submodule = {
    name = "metrics-server";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
