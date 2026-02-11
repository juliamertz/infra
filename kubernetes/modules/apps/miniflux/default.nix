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
    namespace = "miniflux";

    resources.namespaces.miniflux.metadata.labels = {
      "pod-security.kubernetes.io/warn" = "baseline";
      "pod-security.kubernetes.io/warn-version" = "latest";
    };

    resources.cnpgClusters.miniflux-db.spec = {
      instances = 1;
      primaryUpdateStrategy = "unsupervised";
      primaryUpdateMethod = "switchover";
      enableSuperuserAccess = false;
      storage = {
        size = "1Gi";
        storageClass = "longhorn-local";
        resizeInUseVolumes = true;
      };
    };

    resources.deployments.miniflux = {
      metadata.labels.app = "miniflux";
      spec = {
        replicas = 1;
        selector.matchLabels.app = "miniflux";
        template = {
          metadata.labels.app = "miniflux";
          spec.containers = [
            {
              name = "miniflux";
              image = "miniflux/miniflux:2.2.16-distroless";
              securityContext = {
                allowPrivilegeEscalation = false;
                capabilities.drop = ["ALL"];
                seccompProfile.type = "RuntimeDefault";
              };
              ports = [
                {
                  name = "http";
                  containerPort = 8080;
                }
              ];
              env = [
                {
                  name = "BASE_URL";
                  value = "https://news.juliamertz.dev";
                }
                {
                  name = "CREATE_ADMIN";
                  value = "1";
                }
                {
                  name = "RUN_MIGRATIONS";
                  value = "1";
                }
                {
                  name = "LOG_LEVEL";
                  value = "debug";
                }
                {
                  name = "ADMIN_USERNAME";
                  valueFrom.secretKeyRef = {
                    name = "miniflux-credentials";
                    key = "username";
                  };
                }
                {
                  name = "ADMIN_PASSWORD";
                  valueFrom.secretKeyRef = {
                    name = "miniflux-credentials";
                    key = "password";
                  };
                }
                {
                  name = "DATABASE_URL";
                  valueFrom.secretKeyRef = {
                    name = "miniflux-db-app";
                    key = "uri";
                  };
                }
              ];
            }
          ];
        };
      };
    };

    resources.services.miniflux.spec = {
      selector.app = "miniflux";
      ports = [
        {
          protocol = "TCP";
          port = 8080;
          targetPort = 8080;
        }
      ];
    };

    resources.httpRoutes.miniflux.spec = {
      parentRefs = [
        {
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = ["news.juliamertz.dev"];
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
              name = "miniflux";
              port = 8080;
            }
          ];
        }
      ];
    };

    resources.sanInjections.miniflux.spec = {
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
      hostnames = ["news.juliamertz.dev"];
    };
  };

  submodule = {
    name = "miniflux";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
