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

    identity_providers.oidc.clients = [
      {
        client_id = "jellyfin";
        client_name = "Jellyfin";
        client_secret = "ref+sops://secrets/kubenix.yaml#/authelia/oidc/jellyfin/clientSecretDigest";
        public = false;
        authorization_policy = "two_factor";
        require_pkce = true;
        pkce_challenge_method = "S256";
        redirect_uris = ["https://watch.juliamertz.dev/sso/OID/redirect/authelia"];
        scopes = ["openid" "profile" "groups"];
        response_types = ["code"];
        grant_types = ["authorization_code"];
        access_token_signed_response_alg = "none";
        token_endpoint_auth_method = "client_secret_post";
      }
    ];
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
}
