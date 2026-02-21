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
        replicas = 2;
        strategy = {
          type = "RollingUpdate";
          rollingUpdate = {
            maxUnavailable = 1;
            maxSurge = 1;
          };
        };
        selector.matchLabels.app = "attic";
        template = {
          metadata.labels.app = "attic";
          spec = {
            containers = [
              {
                name = "attic";
                image = "ghcr.io/zhaofengli/attic:9736e87439be1b5d40cad1dff004e1d845f8b9e7";
                command = ["atticd" "-f" "/attic/server.toml"];
                securityContext = {
                  allowPrivilegeEscalation = false;
                  capabilities.drop = ["ALL"];
                  seccompProfile.type = "RuntimeDefault";
                };
                ports = [
                  {
                    containerPort = 8080;
                    name = "http";
                  }
                ];
                env = [
                  {
                    name = "RUST_LOG";
                    value = "debug";
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
                volumeMounts = [
                  {
                    name = "config";
                    mountPath = "/attic/server.toml";
                    subPath = "server.toml";
                  }
                ];
                resources = {
                  requests = {
                    cpu = "200m";
                    memory = "300M";
                  };
                  limits = {
                    cpu = "750m";
                    memory = "1Gi";
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
            volumes = [
              {
                name = "config";
                configMap.name = "attic-config";
              }
            ];
          };
        };
      };
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
  };

  submodule = {
    name = "attic";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
