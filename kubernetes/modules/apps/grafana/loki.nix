{
  kubernetes = {
    resources.helmRepositories.grafana.spec = {
      interval = "30m";
      url = "https://grafana.github.io/helm-charts";
    };

    resources.helmReleases.loki-stack.spec = {
      chart.spec = {
        chart = "loki-stack";
        version = "2.10.2";
        sourceRef = {
          kind = "HelmRepository";
          name = "grafana";
        };
        interval = "1m";
      };
      values = {
        loki = {
          enabled = true;
          persistence = {
            enabled = true;
            size = "5Gi";
            storageClassName = "longhorn-local";
          };
          config = {
            auth_enabled = false;
            limits_config.retention_period = "168h";
          };
          resources = {
            requests = {
              cpu = "250m";
              memory = "192Mi";
            };
            limits = {
              cpu = "1000m";
              memory = "512Mi";
            };
          };
        };
        grafana.sidecar.datasources.enabled = false;
        promtail = {
          resources = {
            requests = {
              cpu = "50m";
              memory = "128Mi";
            };
            limits = {
              cpu = "200m";
              memory = "256Mi";
            };
          };
          tolerations = [
            {
              key = "node.kubernetes.io/role";
              operator = "Equal";
              value = "gameserver-node";
              effect = "NoExecute";
            }
            {
              key = "node.kubernetes.io/role";
              operator = "Equal";
              value = "autoscaler-node";
              effect = "NoExecute";
            }
          ];
        };
      };
    };
  };
}
