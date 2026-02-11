{
  pkgs,
  lib,
  ...
}: {
  kubernetes = {
    # Grafana itself is already installed by kube-prometheus-stack

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
  };
}
