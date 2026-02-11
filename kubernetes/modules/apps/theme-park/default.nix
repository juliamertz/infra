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
    namespace = "theme-park";

    resources.namespaces.theme-park.metadata.labels = {
      "pod-security.kubernetes.io/warn" = "baseline";
      "pod-security.kubernetes.io/warn-version" = "latest";
    };

    resources.configMaps.theme-park-nginx.data = {
      "default.conf" = builtins.readFile ./nginx-override.conf;
    };

    resources.deployments.theme-park = {
      metadata.labels.app = "theme-park";
      spec = {
        replicas = 1;
        selector.matchLabels.app = "theme-park";
        template = {
          metadata.labels.app = "theme-park";
          spec = {
            containers = [
              {
                name = "theme-park";
                image = "ghcr.io/themepark-dev/theme.park:1.22.0";
                ports = [
                  {
                    name = "http";
                    containerPort = 80;
                  }
                  {
                    name = "https";
                    containerPort = 443;
                  }
                ];
                volumeMounts = [
                  {
                    name = "nginx-conf";
                    mountPath = "/defaults/nginx/site-confs/default.conf";
                    subPath = "default.conf";
                  }
                ];
                resources = {
                  requests = {
                    cpu = "10m";
                    memory = "20Mi";
                  };
                  limits = {
                    cpu = "50m";
                    memory = "50Mi";
                  };
                };
                readinessProbe = {
                  httpGet = {
                    path = "/";
                    port = 80;
                  };
                  initialDelaySeconds = 3;
                  periodSeconds = 3;
                };
              }
            ];
            volumes = [
              {
                name = "nginx-conf";
                configMap.name = "theme-park-nginx";
              }
            ];
          };
        };
      };
    };

    resources.services.theme-park = {
      metadata.labels.app = "theme-park";
      spec = {
        type = "ClusterIP";
        ports = [
          {
            name = "http";
            protocol = "TCP";
            port = 80;
            targetPort = 80;
          }
        ];
        selector.app = "theme-park";
      };
    };

    resources.referenceGrants.allow-httproute-across-namespaces.spec = {
      from = [
        {
          group = "gateway.networking.k8s.io";
          kind = "HTTPRoute";
          namespace = "authelia";
        }
      ];
      to = [
        {
          group = "";
          kind = "Service";
          name = "theme-park";
        }
      ];
    };

    resources.httpRoutes.theme-park.spec = {
      parentRefs = [
        {
          group = "gateway.networking.k8s.io";
          kind = "Gateway";
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = [
        "theme-park.juliamertz.dev"
      ];
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
              group = "";
              kind = "Service";
              name = "theme-park";
              port = 80;
              weight = 1;
            }
          ];
        }
      ];
    };
    resources.sanInjections.theme-park.spec = {
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
      hostnames = [
        "theme-park.juliamertz.dev"
      ];
    };
  };

  submodule = {
    name = "theme-park";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
