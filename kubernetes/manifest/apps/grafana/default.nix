{
  config,
  kubenix,
  pkgs,
  lib,
  crds,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = {
    namespace = "monitoring";

    resources.namespaces.monitoring.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
      "pod-security.kubernetes.io/audit" = "privileged";
      "pod-security.kubernetes.io/warn" = "privileged";
    };

    resources.configMaps = let
      dashboards = {
        nettenshop = builtins.readFile ./dashboards/nettenshop.json;
        headscale = builtins.readFile (pkgs.fetchurl {
          url = "https://grafana.com/api/dashboards/24516/revisions/3/download";
          sha256 = "sha256-zDJU2fxVnM70O8UevoHSVb/egquMFG52JJJQXDa2LCs=";
        });
        # TODO: kubenix adds the config in an annotation causing the max size to be exceeded
        # cloudnative-pg = builtins.readFile (pkgs.fetchurl {
        #   url = "https://grafana.com/api/dashboards/20417/revisions/4/download";
        #   sha256 = "sha256-+YIJCenupF1TfvIvJwOVMILSZ6wdD1MPIS1E1ylgD6o=";
        # });
      };
      configMapNames = lib.attrNames dashboards |> map (v: "${v}-dashboard");
    in
      lib.genAttrs configMapNames (configMapName: let
        name = lib.removeSuffix "-dashboard" configMapName;
      in {
        metadata.labels.grafana_dashboard = "1";
        data."${name}.json" = dashboards.${name};
      });

    resources.helmRepositories.grafana.spec = {
      interval = "30m";
      url = "https://grafana.github.io/helm-charts";
    };

    resources.helmRepositories.prometheus-community.spec = {
      interval = "30m";
      url = "https://prometheus-community.github.io/helm-charts";
    };

    resources.helmReleases.kube-prometheus-stack.spec = {
      interval = "5m";
      chart.spec = {
        chart = "kube-prometheus-stack";
        version = "81.5.1";
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
            limits = {
              cpu = "250m";
              memory = "512Mi";
            };
          };
          sidecar.resources = {
            requests = {
              cpu = "25m";
              memory = "128Mi";
            };
            limits = {
              cpu = "100m";
              memory = "256Mi";
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

    resources.helmReleases.blackbox-exporter.spec = {
      interval = "5m";
      chart.spec = {
        chart = "prometheus-blackbox-exporter";
        version = "11.8.0";
        sourceRef = {
          kind = "HelmRepository";
          name = "prometheus-community";
        };
        interval = "1m";
      };
      values = {
        fullnameOverride = "blackbox-exporter";
        resources = {
          requests = {
            cpu = "10m";
            memory = "48Mi";
          };
          limits = {
            cpu = "50m";
            memory = "128Mi";
          };
        };
        releaseLabel = true;
        serviceMonitor.enabled = true;
        replicas = 2;
        podDisruptionBudget.maxUnavailable = 1;
        config.modules.http_2xx = {
          prober = "http";
          timeout = "5s";
          http = {
            valid_http_versions = ["HTTP/1.1" "HTTP/2.0"];
            follow_redirects = true;
            preferred_ip_protocol = "ip4";
          };
        };
      };
    };

    resources.deployments.alertmanager-discord = {
      metadata.labels.app = "alertmanager-discord";
      spec = {
        replicas = 2;
        selector.matchLabels.app = "alertmanager-discord";
        template = {
          metadata.labels.app = "alertmanager-discord";
          spec.containers = [
            {
              name = "alertmanager-discord";
              image = "ghcr.io/rogerrum/alertmanager-discord:1.0.7";
              env = [
                {
                  name = "DISCORD_USERNAME";
                  value = "alertmanager";
                }
                {
                  name = "DISCORD_AVATAR_URL";
                  value = "";
                }
                {
                  name = "DISCORD_WEBHOOK";
                  valueFrom.secretKeyRef = {
                    key = "webhookUrl";
                    name = "alertmanager-discord-secret";
                  };
                }
                {
                  name = "LISTEN_ADDRESS";
                  value = "0.0.0.0:9094";
                }
                {
                  name = "VERBOSE";
                  value = "ON";
                }
              ];
              ports = [
                {
                  name = "http";
                  containerPort = 9094;
                }
              ];
              resources = {
                requests = {
                  cpu = "20m";
                  memory = "40Mi";
                };
                limits = {
                  cpu = "20m";
                  memory = "40Mi";
                };
              };
            }
          ];
        };
      };
    };

    resources.services.alertmanager-discord = {
      metadata.labels.app = "alertmanager-discord";
      spec = {
        type = "ClusterIP";
        ports = [
          {
            name = "http";
            port = 9094;
            protocol = "TCP";
            targetPort = 9094;
          }
        ];
        selector.app = "alertmanager-discord";
      };
    };

    resources.httpRoutes.grafana.spec = {
      parentRefs = [
        {
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = [
        "grafana.prod.juliamertz.dev"
        "grafana.juliamertz.dev"
      ];
      rules = [
        {
          backendRefs = [
            {
              name = "kube-prometheus-stack-grafana";
              port = 80;
            }
          ];
        }
      ];
    };

    resources.sanInjections.grafana.spec = {
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
      hostnames = [
        "grafana.prod.juliamertz.dev"
        "grafana.juliamertz.dev"
      ];
    };

    resources.securityPolicies.grafana-auth.spec = {
      targetRefs = [
        {
          group = "gateway.networking.k8s.io";
          kind = "HTTPRoute";
          name = "grafana";
        }
      ];
      extAuth = {
        headersToExtAuth = [
          "accept"
          "cookie"
          "authorization"
          "proxy-authorization"
          "x-forwarded-proto"
        ];
        failOpen = false;
        http = {
          backendRefs = [
            {
              name = "authelia";
              namespace = "authelia";
              port = 80;
            }
          ];
          path = "/api/authz/ext-authz/";
          headersToBackend = [
            "Remote-User"
            "Remote-Groups"
            "Remote-Name"
            "Remote-Email"
            "Location"
            "Set-Cookie"
          ];
        };
      };
    };
  };

  submodule = {
    name = "grafana";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
