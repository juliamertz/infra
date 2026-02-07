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
    namespace = "garage";

    resources.namespaces.garage = {};

    resources.configMaps.garage-config.data = {
      "garage.toml" = builtins.readFile ./garage.toml;
    };

    resources.gitRepositories.garage.spec = {
      interval = "5m0s";
      url = "https://git.deuxfleurs.fr/Deuxfleurs/garage.git";
      ref.tag = "v2.2.0";
    };

    resources.helmReleases.garage.spec = {
      interval = "5m";
      chart.spec = {
        chart = "./script/helm/garage";
        version = "0.9.2";
        sourceRef = {
          kind = "GitRepository";
          name = "garage";
        };
        interval = "1m";
      };
      values = {
        garage.existingConfigMap = "garage-config";
        image.repository = "dxflrs/garage";
        persistence = {
          enabled = true;
          meta = {
            storageClass = "longhorn-local";
            size = "256Mi";
            hostPath = "/var/lib/garage/meta";
          };
          data = {
            storageClass = "longhorn-local";
            size = "1Gi";
            hostPath = "/var/lib/garage/data";
          };
        };
        resources = {
          requests = {
            cpu = "100m";
            memory = "512Mi";
          };
          limits = {
            cpu = "100m";
            memory = "512Mi";
          };
        };
      };
    };

    resources.httpRoutes.garage-web.spec = {
      parentRefs = [
        {
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = [
        "cdn.juliamertz.dev"
        "nettenshop.cdn.juliamertz.dev"
      ];
      rules = [
        {
          backendRefs = [
            {
              name = "garage";
              port = 3902;
            }
          ];
        }
      ];
    };

    resources.httpRoutes.valnetten-web.spec = {
      parentRefs = [
        {
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = ["valnetten.preview.juliamertz.dev"];
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
          filters = [
            {
              type = "URLRewrite";
              urlRewrite.hostname = "valnetten.cdn.juliamertz.dev";
            }
          ];
          backendRefs = [
            {
              name = "garage";
              port = 3902;
            }
          ];
        }
      ];
    };

    resources.httpRoutes.merlijn-web.spec = {
      parentRefs = [
        {
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = ["preview.merlijnvoncken.nl"];
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
          filters = [
            {
              type = "URLRewrite";
              urlRewrite.hostname = "merlijn-site.cdn.juliamertz.dev";
            }
          ];
          backendRefs = [
            {
              name = "garage";
              port = 3902;
            }
          ];
        }
      ];
    };

    resources.sanInjections.garage-web.spec = {
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
      hostnames = [
        "cdn.juliamertz.dev"
        "nettenshop.cdn.juliamertz.dev"
        "valnetten.preview.juliamertz.dev"
        "preview.merlijnvoncken.nl"
      ];
    };

    resources.httpRoutes.garage-api.spec = {
      parentRefs = [
        {
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = ["s3.juliamertz.dev"];
      rules = [
        {
          backendRefs = [
            {
              name = "garage";
              port = 3900;
            }
          ];
        }
      ];
    };

    resources.sanInjections.garage-api.spec = {
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
      hostnames = ["s3.juliamertz.dev"];
    };
  };

  submodule = {
    name = "garage";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
