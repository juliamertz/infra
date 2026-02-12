{
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
    env = [
      {
        name = "AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE";
        value = "/secrets/authelia-secrets/oidc.hmac.key";
      }
    ];
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

    identity_providers.oidc = {
      enabled = true;
      hmac_secret = {
        disabled = true;
      };
      jwks = [
        {
          algorithm = "RS256";
          use = "sig";
          key = {
            disabled = false;
            secret_name = "authelia-secrets";
            path = "/secrets/authelia-secrets/oidc.jwks.pem";
          };
        }
      ];
      clients = let
        mkClient = {
          id,
          name,
          secret,
          redirectUri,
        }: {
          client_id = id;
          client_name = name;
          client_secret = secret;
          public = false;
          authorization_policy = "one_factor";
          require_pkce = true;
          pkce_challenge_method = "S256";
          redirect_uris = [redirectUri];
          scopes = ["openid" "profile" "groups"];
          response_types = ["code"];
          grant_types = ["authorization_code"];
          access_token_signed_response_alg = "none";
          token_endpoint_auth_method = "client_secret_post";
        };
      in [
        (mkClient {
          id = "jellyfin";
          name = "Jellyfin";
          secret = "ref+sops://secrets/kubenix.yaml#/authelia/oidc/jellyfin/clientSecretDigest";
          redirectUri = "https://watch.juliamertz.dev/sso/OID/redirect/authelia";
        })
        (mkClient {
          id = "home-assistant";
          name = "Home Assistant";
          secret = "ref+sops://secrets/kubenix.yaml#/authelia/oidc/homeAssistant/clientSecretDigest";
          redirectUri = "https://hass.juliamertz.dev/auth/oidc/callback";
        })
      ];
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
      {
        key = "OIDC_HMAC_SECRET";
        path = "oidc.hmac.key";
      }
      {
        key = "OIDC_JWKS_KEY";
        path = "oidc.jwks.pem";
      }
    ];
    authelia-db-app.items = [
      {
        key = "password";
        path = "password";
      }
    ];
  };
}
