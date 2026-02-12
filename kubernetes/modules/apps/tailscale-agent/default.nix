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
    namespace = "tailscale-agent";

    resources.namespaces.tailscale-agent.metadata.labels = {
      "pod-security.kubernetes.io/audit" = "privileged";
      "pod-security.kubernetes.io/enforce" = "privileged";
      "pod-security.kubernetes.io/warn" = "privileged";
      "pod-security.kubernetes.io/audit-version" = "latest";
      "pod-security.kubernetes.io/enforce-version" = "latest";
      "pod-security.kubernetes.io/warn-version" = "latest";
    };

    resources.headscaleUsers.kubernetes.spec = {
      headscaleRef = {
        name = "central";
        namespace = "headscale";
      };
    };

    resources.headscalePreauthKeys.agent-auth.spec = {
      ephemeral = true;
      reusable = true;
      expiration = "100y";
      targetSecret = "tailscale-agent-auth";
      user.name = "kubernetes";
    };

    resources.deployments.homelab-route-proxy = {
      metadata.labels.app = "homelab-route-proxy";
      spec = {
        replicas = 1;
        selector.matchLabels.app = "homelab-route-proxy";
        template = {
          metadata = {
            labels.app = "homelab-route-proxy";
            annotations = {
              "headscale.juliamertz.dev/tailscale-inject-sidecar" = "true";
              "headscale.juliamertz.dev/tailscale-extra-args" = "--login-server https://headscale.juliamertz.nl:30443 --accept-routes";
              "headscale.juliamertz.dev/tailscale-auth-secret" = "tailscale-agent-auth";
            };
          };
          spec.containers = [
            {
              name = "caddy";
              image = "caddy:latest";
              command = ["sh" "-c"];
              args = [
                ''
                  cat <<'EOF' > /etc/caddy/Caddyfile
                  ${builtins.readFile ./Caddyfile}
                  EOF
                  caddy run --config /etc/caddy/Caddyfile
                ''
              ];
              ports = [
                {
                  containerPort = 80;
                  protocol = "TCP";
                }
              ];
            }
          ];
        };
      };
    };

    resources.services.homelab-route-proxy.spec = {
      type = "ClusterIP";
      selector.app = "homelab-route-proxy";
      ports = [
        {
          name = "http";
          port = 80;
          protocol = "TCP";
        }
      ];
    };

    resources.httpRoutes.homelab-route-proxy.spec = {
      parentRefs = [
        {
          group = "gateway.networking.k8s.io";
          kind = "Gateway";
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = [
        "hass.juliamertz.dev"
        "hass.juliamertz.nl"
      ];
      rules = [
        {
          matches = [
            {
              path = {
                type = "PathPrefix";
                value = "/auth/authorize";
              };
            }
          ];
          filters = [
            {
              type = "RequestRedirect";
              requestRedirect = {
                path = {
                  type = "ReplaceFullPath";
                  replaceFullPath = "/auth/oidc/welcome";
                };
                statusCode = 302;
              };
            }
          ];
        }
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
              name = "homelab-route-proxy";
              port = 80;
              weight = 1;
            }
          ];
        }
      ];
    };

    resources.httpRoutes.jellyfin.spec = {
      parentRefs = [
        {
          group = "gateway.networking.k8s.io";
          kind = "Gateway";
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = [
        "watch.juliamertz.dev"
        "watch.juliamertz.nl"
      ];
      rules = [
        {
          matches = [
            {
              path = {
                type = "PathPrefix";
                value = "/sso/";
              };
            }
          ];
          backendRefs = [
            {
              group = "";
              kind = "Service";
              name = "homelab-route-proxy";
              port = 80;
              weight = 1;
            }
          ];
        }
        {
          matches = [
            {
              path = {
                type = "PathPrefix";
                value = "/";
              };
              headers = [
                {
                  name = "Cookie";
                  type = "RegularExpression";
                  value = ".*authelia_session.*";
                }
              ];
            }
          ];
          backendRefs = [
            {
              group = "";
              kind = "Service";
              name = "homelab-route-proxy";
              port = 80;
              weight = 1;
            }
          ];
        }
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
              type = "RequestRedirect";
              requestRedirect = {
                path = {
                  type = "ReplaceFullPath";
                  replaceFullPath = "/sso/OID/start/authelia";
                };
                statusCode = 302;
              };
            }
          ];
        }
      ];
    };

    resources.sanInjections.homelab-route-proxy.spec = {
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
      hostnames = [
        "hass.juliamertz.dev"
        "hass.juliamertz.nl"
        "watch.juliamertz.dev"
        "watch.juliamertz.nl"
      ];
    };

    # resources.securityPolicies.homelab-route-proxy-auth.spec = {
    #   targetRefs = [
    #     {
    #       group = "gateway.networking.k8s.io";
    #       kind = "HTTPRoute";
    #       name = "homelab-route-proxy";
    #     }
    #   ];
    #   extAuth = {
    #     headersToExtAuth = [
    #       "accept"
    #       "cookie"
    #       "authorization"
    #       "proxy-authorization"
    #       "x-forwarded-proto"
    #     ];
    #     failOpen = false;
    #     http = {
    #       backendRefs = [
    #         {
    #           name = "authelia";
    #           namespace = "authelia";
    #           port = 80;
    #         }
    #       ];
    #       path = "/api/authz/ext-authz/";
    #       headersToBackend = [
    #         "Remote-User"
    #         "Remote-Groups"
    #         "Remote-Name"
    #         "Remote-Email"
    #         "Location"
    #         "Set-Cookie"
    #       ];
    #     };
    #   };
    # };
  };

  submodule = {
    name = "tailscale-agent";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
