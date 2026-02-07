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
    namespace = "adsb-proxy";

    resources.namespaces.adsb-proxy.metadata.labels = {
      "pod-security.kubernetes.io/warn" = "baseline";
      "pod-security.kubernetes.io/warn-version" = "latest";
    };

    resources.deployments.adsb-proxy = {
      metadata.labels.app = "adsb-proxy";
      spec = {
        replicas = 1;
        selector.matchLabels.app = "adsb-proxy";
        template = {
          metadata.labels.app = "adsb-proxy";
          spec = {
            containers = [
              {
                name = "nginx";
                image = "nginx";
                ports = [
                  {
                    name = "http";
                    containerPort = 80;
                  }
                ];
                volumeMounts = [
                  {
                    name = "config";
                    mountPath = "/etc/nginx/nginx.conf";
                    subPath = "nginx.conf";
                  }
                ];
              }
            ];
            volumes = [
              {
                name = "config";
                configMap.name = "adsb-proxy-config";
              }
            ];
          };
        };
      };
    };

    resources.configMaps.adsb-proxy-config.data = {
      "nginx.conf" = builtins.readFile ./nginx.conf;
    };

    resources.services.adsb-proxy.spec = {
      selector.app = "adsb-proxy";
      ports = [
        {
          port = 8000;
          targetPort = "http";
          protocol = "TCP";
        }
      ];
    };

    resources.sanInjections.adsb-api-proxy.spec = {
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
      hostnames = ["adsb-proxy.juliamertz.dev"];
    };

    resources.httpRoutes.adsb-proxy.spec = {
      parentRefs = [
        {
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = ["adsb-proxy.juliamertz.dev"];
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
              name = "adsb-proxy";
              port = 8000;
            }
          ];
        }
      ];
    };

    resources.backendTrafficPolicies.rate-limit-adsb-proxy.spec = {
      targetRef = {
        group = "gateway.networking.k8s.io";
        kind = "HTTPRoute";
        name = "adsb-proxy";
      };
      loadBalancer.type = "LeastRequest";
      rateLimit = {
        type = "Global";
        global.rules = [
          {
            limit = {
              requests = 5;
              unit = "Second";
            };
          }
        ];
      };
    };
  };

  submodule = {
    name = "adsb-proxy";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
