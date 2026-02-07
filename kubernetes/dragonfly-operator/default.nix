{
  config,
  lib,
  pkgs,
  kubenix,
  ...
}: {
  imports = with kubenix.modules; [submodules k8s];

  kubernetes = {
    namespace = "dragonfly-operator";

    resources.namespaces.dragonfly-operator = {};

    resources.helmrepositories.dragonfly.spec = {
      type = "oci";
      url = "oci://ghcr.io/dragonflydb/dragonfly-operator/helm";
    };

    resources.helmreleases.dragonfly-operator.spec = {
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
}
