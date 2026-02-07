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
    resources.httpRoutes.merlijn-redirects.spec = {
      hostnames = [
        "merlijnvoncken.nl"
        "merlijnvoncken.com"
      ];
      parentRefs = [
        {
          group = "gateway.networking.k8s.io";
          kind = "Gateway";
          name = "shared";
          namespace = "default";
        }
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
          filters = [
            {
              type = "RequestRedirect";
              requestRedirect = {
                scheme = "https";
                hostname = "instagram.com";
                path = {
                  type = "ReplaceFullPath";
                  replaceFullPath = "/merlijnvoncken";
                };
                statusCode = 302;
              };
            }
          ];
        }
      ];
    };

    resources.sanInjections.merlijn-tls.spec = {
      hostnames = [
        "merlijnvoncken.nl"
        "merlijnvoncken.com"
      ];
      targetCertificate = {
        name = "gateway-tls";
        namespace = "default";
      };
    };
  };

  submodule = {
    name = "routes";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
