{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes = {
    gatewayclass = {
      attrName = "gatewayclasses";
      group = "gateway.networking.k8s.io";
      kind = "GatewayClass";
      version = "v1";
      module = with lib; {
        options = {
          controllerName = mkOption {
            type = types.str;
          };
          parametersRef = mkOption {
            type = types.nullOr (types.submodule (_: {
              options = {
                group = mkOption {type = types.str;};
                kind = mkOption {type = types.str;};
                name = mkOption {type = types.str;};
                namespace = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
              };
            }));
            default = null;
          };
        };
      };
    };

    envoyproxy = {
      attrName = "envoyproxies";
      group = "gateway.envoyproxy.io";
      kind = "EnvoyProxy";
      version = "v1alpha1";
      module = with lib; let
        envoyServiceType = types.submodule (_: {
          options = {
            type = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            annotations = mkOption {
              type = types.attrsOf types.str;
              default = {};
            };
          };
        });
        envoyDeploymentType = types.submodule (_: {
          options = {
            replicas = mkOption {
              type = types.nullOr types.int;
              default = null;
            };
            strategy = mkOption {
              type = types.nullOr types.attrs;
              default = null;
            };
            pod = mkOption {
              type = types.nullOr types.attrs;
              default = null;
            };
          };
        });
      in {
        options = {
          provider = mkOption {
            type = types.submodule (_: {
              options = {
                type = mkOption {type = types.str;};
                kubernetes = mkOption {
                  type = types.nullOr (types.submodule (_: {
                    options = {
                      envoyService = mkOption {
                        type = types.nullOr envoyServiceType;
                        default = null;
                      };
                      envoyDeployment = mkOption {
                        type = types.nullOr envoyDeploymentType;
                        default = null;
                      };
                      envoyHpa = mkOption {
                        type = types.nullOr types.attrs;
                        default = null;
                      };
                      envoyPDB = mkOption {
                        type = types.nullOr types.attrs;
                        default = null;
                      };
                    };
                  }));
                  default = null;
                };
              };
            });
          };
        };
      };
    };

    httproute = {
      attrName = "httpRoutes";
      group = "gateway.networking.k8s.io";
      kind = "HTTPRoute";
      version = "v1";
      module = with lib; let
        parentRefType = types.submodule (_: {
          options = {
            name = mkOption {type = types.str;};
            namespace = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            sectionName = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
          };
        });
        backendRefType = types.submodule (_: {
          options = {
            name = mkOption {type = types.str;};
            port = mkOption {type = types.int;};
            namespace = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            group = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            kind = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            weight = mkOption {
              type = types.nullOr types.int;
              default = null;
            };
          };
        });
        pathMatchType = types.submodule (_: {
          options = {
            type = mkOption {type = types.str;};
            value = mkOption {type = types.str;};
          };
        });
        matchType = types.submodule (_: {
          options = {
            path = mkOption {
              type = types.nullOr pathMatchType;
              default = null;
            };
            method = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            headers = mkOption {
              type = types.nullOr (types.listOf types.attrs);
              default = null;
            };
            queryParams = mkOption {
              type = types.nullOr (types.listOf types.attrs);
              default = null;
            };
          };
        });
        ruleType = types.submodule (_: {
          options = {
            matches = mkOption {
              type = types.nullOr (types.listOf matchType);
              default = null;
            };
            backendRefs = mkOption {
              type = types.nullOr (types.listOf backendRefType);
              default = null;
            };
            filters = mkOption {
              type = types.nullOr (types.listOf types.attrs);
              default = null;
            };
          };
        });
      in {
        options = {
          parentRefs = mkOption {
            type = types.listOf parentRefType;
          };
          hostnames = mkOption {
            type = types.listOf types.str;
          };
          rules = mkOption {
            type = types.listOf ruleType;
          };
        };
      };
    };

    referencegrant = {
      attrName = "referenceGrants";
      group = "gateway.networking.k8s.io";
      kind = "ReferenceGrant";
      version = "v1beta1";
      module = with lib; let
        fromType = types.submodule (_: {
          options = {
            group = mkOption {type = types.str;};
            kind = mkOption {type = types.str;};
            namespace = mkOption {type = types.str;};
          };
        });
        toType = types.submodule (_: {
          options = {
            group = mkOption {type = types.str;};
            kind = mkOption {type = types.str;};
            name = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
          };
        });
      in {
        options = {
          from = mkOption {
            type = types.listOf fromType;
          };
          to = mkOption {
            type = types.listOf toType;
          };
        };
      };
    };
  };
}
