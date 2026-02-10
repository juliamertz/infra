{
  kubernetes = {
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
          inline = builtins.readFile ./route-ext.lua;
        }
      ];
    };
  };
}
