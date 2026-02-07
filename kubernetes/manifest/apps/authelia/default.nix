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
    namespace = "authelia";

    resources.namespaces.authelia = {};

    resources.cnpgClusters.authelia-db.spec = {
      instances = 2;
      primaryUpdateStrategy = "unsupervised";
      primaryUpdateMethod = "switchover";
      enableSuperuserAccess = false;
      storage = {
        size = "1Gi";
        storageClass = "longhorn-local";
        resizeInUseVolumes = true;
      };
      bootstrap = {
        initdb = {
          database = "authelia";
          owner = "authelia";
        };
      };
    };

    resources.dragonflies.authelia-cache.spec = {
      image = "docker.dragonflydb.io/dragonflydb/dragonfly:latest";
      replicas = 1;
      resources = {
        limits = {
          cpu = "100m";
          memory = "512Mi";
        };
        requests = {
          cpu = "100m";
          memory = "512Mi";
        };
      };
    };

    resources.helmRepositories.authelia.spec = {
      interval = "1h";
      url = "https://charts.authelia.com";
    };

    resources.helmReleases.authelia.spec = {
      interval = "1h";
      chart.spec = {
        chart = "authelia";
        version = "0.10.49";
        sourceRef = {
          kind = "HelmRepository";
          name = "authelia";
        };
      };
      values = {
        pod = {
          kind = "Deployment";
          replicas = 2;
          resources = {
            requests = {
              cpu = "20m";
              memory = "50Mi";
            };
            limits = {
              cpu = "200m";
              memory = "500Mi";
            };
          };
          extraVolumeMounts = [
            {
              name = "users-db";
              mountPath = "/config/users.yml";
              subPath = "USERS_DATABASE";
            }
          ];
          extraVolumes = [
            {
              name = "users-db";
              secret = {
                secretName = "authelia-secrets";
                items = [
                  {
                    key = "USERS_DATABASE";
                    path = "USERS_DATABASE";
                  }
                ];
              };
            }
          ];
        };

        configMap = {
          theme = "dark";

          log.level = "debug";

          default_2fa_method = "totp";

          server.endpoints.authz.ext-authz = {
            implementation = "ExtAuthz";
            authn_strategies = [
              {name = "CookieSession";}
            ];
          };

          authentication_backend.file = {
            enabled = true;
            path = "/config/users.yml";
          };

          session = {
            name = "authelia_session";
            same_site = "lax";
            inactivity = "5m";
            expiration = "1h";
            remember_me = "1M";
            cookies = [
              {
                domain = "juliamertz.dev";
                subdomain = "auth";
                authelia_url = "https://auth.juliamertz.dev";
                default_redirection_url = "https://hass.juliamertz.dev";
              }
              {
                domain = "merlijnvoncken.nl";
                subdomain = "auth";
                authelia_url = "https://auth.merlijnvoncken.nl";
                default_redirection_url = "https://admin.merlijnvoncken.nl";
                name = "authelia_session_nl";
              }
              {
                domain = "merlijnvoncken.com";
                subdomain = "auth";
                authelia_url = "https://auth.merlijnvoncken.com";
                default_redirection_url = "https://admin.merlijnvoncken.com";
              }
            ];
            redis = {
              enabled = true;
              host = "authelia-cache.authelia.svc.cluster.local";
              port = 6379;
            };
          };

          storage.postgres = {
            enabled = true;
            address = "tcp://authelia-db-rw.authelia.svc.cluster.local:5432";
            database = "authelia";
            username = "authelia";
            password = {
              disabled = false;
              secret_name = "authelia-db-app";
              path = "password";
            };
          };

          access_control = {
            default_policy = "one_factor";
            rules = [
              {
                domain = "auth.juliamertz.dev";
                policy = "bypass";
              }
              {
                domain = "hass.juliamertz.dev";
                policy = "bypass";
                resources = [
                  "^/auth/.*$"
                  "^/api/websocket$"
                  "^/api/webhook/.*$"
                ];
              }
              {
                domain = "*.juliamertz.dev";
                policy = "one_factor";
              }
              {
                domain = "*.merlijnvoncken.*";
                policy = "one_factor";
              }
            ];
          };

          notifier.filesystem = {
            enabled = true;
            filename = "/config/notification.txt";
          };
        };

        persistence.enabled = false;

        secret.additionalSecrets = {
          authelia-secrets.items = [
            {
              key = "SESSION_SECRET";
              path = "session.encryption.key";
            }
            {
              key = "STORAGE_ENCRYPTION_KEY";
              path = "storage.encryption.key";
            }
          ];
          authelia-db-app.items = [
            {
              key = "password";
              path = "password";
            }
          ];
        };
      };
    };

    resources.httpRoutes.authelia.spec = {
      parentRefs = [
        {
          name = "shared";
          namespace = "default";
        }
      ];
      hostnames = [
        "auth.juliamertz.dev"
        "auth.merlijnvoncken.nl"
        "auth.merlijnvoncken.com"
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
              name = "authelia";
              port = 80;
            }
          ];
        }
        {
          matches = [
            {
              path = {
                type = "PathPrefix";
                value = "/themepark";
              };
            }
          ];
          backendRefs = [
            {
              group = "";
              kind = "Service";
              name = "theme-park";
              namespace = "theme-park";
              port = 80;
            }
          ];
        }
      ];
    };

    resources.sanInjections.authelia.spec = {
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
      hostnames = [
        "auth.juliamertz.dev"
        "auth.merlijnvoncken.nl"
        "auth.merlijnvoncken.com"
      ];
    };

    resources.envoyExtensionPolicies.inject-css.spec = {
      targetRefs = [
        {
          group = "gateway.networking.k8s.io";
          kind = "HTTPRoute";
          name = "authelia";
        }
      ];
      lua = [
        {
          type = "Inline";
          inline = ''
            local theme_url = '/themepark/css/base/authelia/rose-pine-moon.css'
            local css_link = '<link rel="stylesheet" type="text/css" href="' .. theme_url .. '">'

            function envoy_on_response(res)
              local content_type = res:headers():get("content-type") or "none"

              if string.match(content_type, "text/html") then
                local body = res:body()
                if body then
                  local original = body:getBytes(0, body:length())
                  local modified = string.gsub(original, "</head>", css_link .. "</head>")
                  body:setBytes(modified)
                  res:headers():replace("content-length", tostring(#modified))
                end
              end
            end
          '';
        }
      ];
    };

    resources.referenceGrants.allow-securitypolicy-from-tailscale-agent.spec = {
      from = [
        {
          group = "gateway.envoyproxy.io";
          kind = "SecurityPolicy";
          namespace = "tailscale-agent";
        }
        {
          group = "gateway.envoyproxy.io";
          kind = "SecurityPolicy";
          namespace = "monitoring";
        }
        {
          group = "gateway.envoyproxy.io";
          kind = "SecurityPolicy";
          namespace = "merlijn-portfolio";
        }
        {
          group = "gateway.envoyproxy.io";
          kind = "SecurityPolicy";
          namespace = "miniflux";
        }
      ];
      to = [
        {
          group = "";
          kind = "Service";
          name = "authelia";
        }
      ];
    };
  };

  submodule = {
    name = "authelia";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
