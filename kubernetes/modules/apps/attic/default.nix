{
  config,
  kubenix,
  crds,
  ...
}: let
  # image = "ghcr.io/zhaofengli/attic:9736e87439be1b5d40cad1dff004e1d845f8b9e7";
  # fork with split internal and public-endpoint
  image = "ghcr.io/covert8/attic:88662706f8e33ecd36beb77e2086b0811d3507aa";

  securityContext = {
    allowPrivilegeEscalation = false;
    capabilities.drop = ["ALL"];
    seccompProfile.type = "RuntimeDefault";
  };

  env = [
    {
      name = "RUST_LOG";
      value = "info";
    }
    {
      name = "ATTIC_SERVER_DATABASE_URL";
      valueFrom.secretKeyRef = {
        name = "attic-db-app";
        key = "uri";
      };
    }
    {
      name = "ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64";
      valueFrom.secretKeyRef = {
        name = "attic-token";
        key = "token";
      };
    }
    {
      name = "AWS_ACCESS_KEY_ID";
      valueFrom.secretKeyRef = {
        name = "storage-credentials";
        key = "accessKey";
      };
    }
    {
      name = "AWS_SECRET_ACCESS_KEY";
      valueFrom.secretKeyRef = {
        name = "storage-credentials";
        key = "secretKey";
      };
    }
  ];

  configVolume = {
    name = "config";
    configMap.name = "attic-config";
  };

  configMount = {
    name = "config";
    mountPath = "/attic/server.toml";
    subPath = "server.toml";
  };
in {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = {
    namespace = "attic";

    resources.namespaces.attic.metadata.labels = {
      "pod-security.kubernetes.io/warn" = "baseline";
      "pod-security.kubernetes.io/warn-version" = "latest";
    };

    resources.cnpgClusters.attic-db.spec = {
      instances = 2;
      primaryUpdateStrategy = "unsupervised";
      primaryUpdateMethod = "switchover";
      storage.size = "1Gi";
    };

    resources.configMaps.attic-config.data = {
      "server.toml" = ''
        listen = "0.0.0.0:8080"
        api-endpoint = "https://attic.juliamertz.dev/"

        [database]

        [storage]
        type = "s3"
        endpoint = "http://garage.garage:3900"
        public-endpoint = "https://s3.juliamertz.dev"
        region = "garage"
        bucket = "attic-cache"
        force_path_style = true

        [chunking]
        nar-size-threshold = 65536
        min-size = 16384
        avg-size = 65536
        max-size = 262144

        [compression]
        type = "zstd"
      '';
    };

    resources.deployments.attic = {
      metadata.labels.app = "attic";
      spec = {
        selector.matchLabels.app = "attic";
        template = {
          metadata.labels.app = "attic";
          spec = {
            initContainers = [
              {
                name = "migrations";
                inherit image securityContext env;
                command = ["atticd" "-f" "/attic/server.toml" "--mode" "db-migrations"];
                volumeMounts = [configMount];
              }
            ];
            containers = [
              {
                name = "attic";
                inherit image securityContext env;
                command = ["atticd" "-f" "/attic/server.toml" "--mode" "api-server"];
                ports = [
                  {
                    containerPort = 8080;
                    name = "http";
                  }
                ];
                volumeMounts = [configMount];
                resources = {
                  requests = {
                    cpu = "250m";
                    memory = "500Mi";
                  };
                  limits = {
                    cpu = "500m";
                    memory = "750Mi";
                  };
                };
                livenessProbe = {
                  httpGet = {
                    path = "/";
                    port = 8080;
                  };
                  initialDelaySeconds = 2;
                  periodSeconds = 5;
                  timeoutSeconds = 5;
                };
                readinessProbe = {
                  httpGet = {
                    path = "/";
                    port = 8080;
                  };
                  initialDelaySeconds = 3;
                  periodSeconds = 5;
                  timeoutSeconds = 6;
                };
              }
            ];
            volumes = [configVolume];
          };
        };
      };
    };

    resources.deployments.attic-gc = {
      metadata.labels.app = "attic-gc";
      spec = {
        replicas = 1;
        selector.matchLabels.app = "attic-gc";
        template = {
          metadata.labels.app = "attic-gc";
          spec = {
            containers = [
              {
                name = "attic-gc";
                inherit image securityContext env;
                command = ["atticd" "-f" "/attic/server.toml" "--mode" "garbage-collector"];
                volumeMounts = [configMount];
                resources = {
                  requests = {
                    cpu = "50m";
                    memory = "48Mi";
                  };
                  limits = {
                    cpu = "200m";
                    memory = "128Mi";
                  };
                };
              }
            ];
            volumes = [configVolume];
          };
        };
      };
    };

    resources.horizontalPodAutoscalers.attic.spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        name = "attic";
      };
      minReplicas = 1;
      maxReplicas = 3;
      metrics = [
        {
          type = "Resource";
          resource = {
            name = "cpu";
            target = {
              type = "Utilization";
              averageUtilization = 70;
            };
          };
        }
        {
          type = "Resource";
          resource = {
            name = "memory";
            target = {
              type = "Utilization";
              averageUtilization = 85;
            };
          };
        }
      ];
    };

    resources.services.attic.spec = {
      selector.app = "attic";
      type = "ClusterIP";
      ports = [
        {
          port = 8080;
          targetPort = 8080;
          name = "http";
        }
      ];
    };

    resources.sanInjections.attic-tls.spec = {
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
      hostnames = ["attic.juliamertz.dev"];
    };

    resources.httpRoutes.attic.spec = {
      parentRefs = [
        {
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = ["attic.juliamertz.dev"];
      rules = [
        {
          matches = [
            {
              path = {
                type = "PathPrefix";
                value = "/";
              };
            }
          ];
          backendRefs = [
            {
              name = "attic";
              port = 8080;
            }
          ];
          timeouts = {
            request = "0s";
            backendRequest = "0s";
          };
        }
      ];
    };

    resources.backendTrafficPolicies.rate-limit.spec = {
      targetRef = {
        group = "gateway.networking.k8s.io";
        kind = "HTTPRoute";
        name = "attic";
      };
      loadBalancer.type = "LeastRequest";
      rateLimit = {
        type = "Global";
        global.rules = [
          {
            limit = {
              requests = 100;
              unit = "Second";
            };
          }
        ];
      };
    };
  };

  submodule = {
    name = "attic";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
