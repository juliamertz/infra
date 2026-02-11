{
  kubernetes = {
    resources.helmRepositories.prometheus-community.spec = {
      interval = "30m";
      url = "https://prometheus-community.github.io/helm-charts";
    };

    resources.helmReleases.kube-prometheus-stack.spec = {
      interval = "5m";
      chart.spec = {
        chart = "kube-prometheus-stack";
        version = "81.6.2";
        sourceRef = {
          kind = "HelmRepository";
          name = "prometheus-community";
        };
        interval = "1m";
      };
      values = {
        grafana = {
          resources = {
            requests = {
              cpu = "50m";
              memory = "256Mi";
            };
          };
          sidecar.resources = {
            requests = {
              cpu = "25m";
              memory = "128Mi";
            };
          };
          admin = {
            existingSecret = "kube-prometheus-stack-grafana";
            passwordKey = "admin-password";
            userKey = "admin-user";
          };
          adminPassword = "";
          adminUser = "";
          additionalDataSources = [
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://loki-stack:3100";
              jsonData.maxLines = 1000;
              version = 1;
              editable = true;
              isDefault = false;
            }
          ];
        };
        prometheusOperator = {
          resources = {
            requests = {
              cpu = "10m";
              memory = "64Mi";
            };
            limits = {
              cpu = "50m";
              memory = "256Mi";
            };
          };
          prometheusConfigReloader.resources = {
            requests = {
              cpu = "10m";
              memory = "32Mi";
            };
            limits = {
              cpu = "50m";
              memory = "64Mi";
            };
          };
        };
        kube-state-metrics = {
          collectors = [
            "nodes"
            "pods"
            "deployments"
            "statefulsets"
            "daemonsets"
            "jobs"
            "cronjobs"
          ];
          resources = {
            requests = {
              cpu = "10m";
              memory = "64Mi";
            };
            limits = {
              cpu = "50m";
              memory = "256Mi";
            };
          };
        };
        prometheus-node-exporter.resources = {
          requests = {
            cpu = "15m";
            memory = "32Mi";
          };
          limits = {
            cpu = "100m";
            memory = "128Mi";
          };
        };
        prometheus.prometheusSpec = {
          scrapeInterval = "60s";
          resources = {
            requests = {
              cpu = "200m";
              memory = "512Mi";
            };
            limits = {
              cpu = "500m";
              memory = "1Gi";
            };
          };
          metricRelabelings = [
            {
              sourceLabels = ["namespace"];
              regex = "(kube-system|hetzner-system|longhorn-system|monitoring)";
              action = "drop";
            }
          ];
          podMonitorSelectorNilUsesHelmValues = false;
          serviceMonitorSelectorNilUsesHelmValues = false;
          probeSelectorNilUsesHelmValues = false;
          podMonitorSelector = {};
          podMonitorNamespaceSelector = {};
          probeSelector = {};
          serviceMonitorSelector = {};
          serviceMonitorNamespaceSelector = {};
          probeNamespaceSelector = {};
          storageSpec.volumeClaimTemplate.spec = {
            storageClassName = "hcloud-volumes";
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "10Gi";
          };
        };
        alertmanager = {
          enabled = true;
          alertmanagerSpec.resources = {
            requests = {
              cpu = "15m";
              memory = "64Mi";
            };
            limits = {
              cpu = "50m";
              memory = "128Mi";
            };
          };
          config = {
            route = {
              group_by = ["alertname"];
              group_wait = "20s";
              group_interval = "5m";
              repeat_interval = "3h";
              receiver = "discord_webhook";
            };
            receivers = [
              {
                name = "discord_webhook";
                webhook_configs = [
                  {url = "http://alertmanager-discord:9094";}
                ];
              }
            ];
          };
        };
      };
    };
  };
}
