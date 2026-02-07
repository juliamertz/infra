{
  config,
  kubenix,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    ../../type/fluxcd.nix
    ../../type/dragonfly-operator.nix
  ];

  config.kubernetes = {
    namespace = "dragonfly-operator";

    resources.namespaces.dragonfly-operator = {};

    resources.helmRepositories.dragonfly.spec = {
      type = "oci";
      url = "oci://ghcr.io/dragonflydb/dragonfly-operator/helm";
    };

    resources.helmReleases.dragonfly-operator.spec = {
      interval = "5m";
      chart.spec = {
        chart = "dragonfly-operator";
        version = "v1.4.0";
        sourceRef = {
          kind = "HelmRepository";
          name = "dragonfly";
        };
      };
      values = {
        crds.install = true;

        podSecurityContext.fsGroup = 2000;

        securityContext = {
          capabilities.drop = ["ALL"];
          readOnlyRootFilesystem = true;
          runAsNonRoot = true;
          runAsUser = 1000;
        };

        serviceMonitor.enabled = true;

        prometheusRule = {
          enabled = true;
          spec = [
            {
              alert = "DragonflyMissing";
              expr = "absent(dragonfly_uptime_in_seconds) == 1";
              "for" = "0m";
              labels.severity = "critical";
              annotations = {
                summary = "Dragonfly is missing";
                description = "Dragonfly is missing";
              };
            }
          ];
        };
      };
    };
  };

  config.submodule = {
    name = "dragonfly-operator";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
