{
  config,
  kubenix,
  crds,
  util,
  ...
}: let
  inherit (util) configMapValueRef;
in {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = let
    name = "shared";
    targetRef = {
      group = "gateway.networking.k8s.io";
      kind = "Gateway";
      inherit name;
    };
  in {
    resources.gateways.${name}.spec = {
      gatewayClassName = "envoy";
      listeners = [
        {
          name = "http";
          protocol = "HTTP";
          port = 80;
          allowedRoutes.namespaces.from = "All";
        }
        {
          name = "https";
          protocol = "HTTPS";
          port = 443;
          allowedRoutes.namespaces.from = "All";
          tls = {
            mode = "Terminate";
            certificateRefs = [
              {
                kind = "Secret";
                name = "tls-cert-gateway";
              }
            ];
          };
        }
      ];
    };

    resources.backendTrafficPolicies.rate-limit.spec = {
      inherit targetRef;
      loadBalancer.type = "LeastRequest";
      rateLimit = {
        type = "Global";
        global.rules = [
          {
            limit = {
              requests = 500;
              unit = "Minute";
            };
          }
        ];
      };
    };

    resources.clientTrafficPolicies.proxy-protocol.spec = {
      inherit targetRef;
      proxyProtocol = {};
      clientIPDetection = {
        xForwardedFor = {
          numTrustedHops = 1;
        };
      };
    };

    resources.configMaps.envoy-lua-extension.data = {
      "extension.lua" = builtins.readFile ./extension.lua;
    };

    resources.envoyExtensionPolicies.envoy-lua-extension.spec = {
      targetRefs = [targetRef];
      lua = [(configMapValueRef "envoy-lua-extension")];
    };
  };

  submodule = {
    name = "gateway";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
