{
  config,
  kubenix,
  crds,
  lib,
  util,
  ...
}: let
  inherit (util) configMapValueRef;
  args = config.submodule.args;
in {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  options.submodule.args = with lib; {
    name = mkOption {
      type = types.str;
      default = "shared";
    };

    gatewayClassName = mkOption {
      type = types.str;
      default = "envoy";
    };

    tlsCertSecret = mkOption {
      type = types.str;
      default = "tls-cert-gateway";
    };

    rateLimit = {
      requests = mkOption {
        type = types.int;
        default = 500;
      };

      unit = mkOption {
        type = types.enum ["Second" "Minute" "Hour" "Day"];
        default = "Minute";
      };
    };

  };

  config.kubernetes = let
    name = args.name;
    targetRef = {
      group = "gateway.networking.k8s.io";
      kind = "Gateway";
      inherit name;
    };
  in {
    resources.gateways.${name}.spec = {
      gatewayClassName = args.gatewayClassName;
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
                name = args.tlsCertSecret;
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
              requests = args.rateLimit.requests;
              unit = args.rateLimit.unit;
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

  config.submodule = {
    name = "gateway";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
