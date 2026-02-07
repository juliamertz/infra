{
  config,
  lib,
  pkgs,
  kubenix,
  ...
}: {
  imports = with kubenix.modules; [submodules k8s];

  kubernetes = {
    namespace = "kube-system";

    resources.helmrepositories.metrics-server.spec = {
      url = "https://kubernetes-sigs.github.io/metrics-server/";
    };

    resources.helmreleases.metrics-server.spec = {
      interval = "5m";
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
}
