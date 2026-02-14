{
  config,
  kubenix,
  crds,
  lib,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = {
    namespace = "chartmuseum";

    resources.namespaces.chartmuseum = {};

    resources.helmRepositories.chartmuseum.spec = {
      url = "https://chartmuseum.github.io/charts";
    };

    resources.secrets.s3-credentials.stringData = lib.mapAttrs (_: path: "ref+sops://secrets/kubenix.yaml#${path}") {
      keyId = "/s3/bucket/charts/keyId";
      secretKey = "/s3/bucket/charts/secretKey";
    };

    resources.helmReleases.chartmuseum.spec = {
      chart.spec = {
        chart = "chartmuseum";
        version = "3.10.4";
        sourceRef = {
          kind = "HelmRepository";
          name = "chartmuseum";
        };
      };
      values = {
        replicaCount = 1;
        env = {
          open = {
            STORAGE = "amazon";
            STORAGE_AMAZON_BUCKET = "charts";
            STORAGE_AMAZON_REGION = "garage";
            STORAGE_AMAZON_ENDPOINT = "http://garage.garage:3900";
            STORAGE_AMAZON_PREFIX = "";
            DISABLE_STATEFILES = true;
            DISABLE_API = false;
            ALLOW_OVERWRITE = true;
            DELETE = true;
            CHART_URL = "";
            DEPTH = 0;
          };
          existingSecret = "s3-credentials";
          existingSecretMappings = {
            AWS_ACCESS_KEY_ID = "keyId";
            AWS_SECRET_ACCESS_KEY = "secretKey";
          };
        };
        resources = {
          requests = {
            cpu = "10m";
            memory = "64Mi";
          };
          limits = {
            cpu = "20m";
            memory = "128Mi";
          };
        };
        persistence.enabled = false;
      };
    };

    resources.httpRoutes.chartmuseum.spec = {
      parentRefs = [
        {
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = ["charts.juliamertz.dev"];
      rules = [
        {
          filters = [
            {
              type = "RequestRedirect";
              requestRedirect = {
                path = {
                  type = "ReplaceFullPath";
                  replaceFullPath = "/";
                };
                statusCode = 302;
              };
            }
          ];
          matches = [
            {
              path = {
                type = "PathPrefix";
                value = "/api";
              };
            }
            {
              path = {
                type = "PathPrefix";
                value = "/info";
              };
            }
          ];
        }
        {
          backendRefs = [
            {
              name = "chartmuseum";
              port = 8080;
            }
          ];
          matches = [
            {method = "GET";}
            {method = "HEAD";}
          ];
        }
      ];
    };

    resources.sanInjections.chartmuseum.spec = {
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
      hostnames = ["charts.juliamertz.dev"];
    };
  };

  submodule = {
    name = "chartmuseum";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
