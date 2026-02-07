{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes.certificate = {
    attrName = "certificates";
    group = "cert-manager.io";
    kind = "Certificate";
    version = "v1";
    module = with lib; {
      options = {
        secretName = mkOption {type = types.str;};
        issuerRef = mkOption {
          type = types.submodule (_: {
            options = {
              name = mkOption {type = types.str;};
              kind = mkOption {
                type = types.str;
                default = "ClusterIssuer";
              };
            };
          });
        };
        dnsNames = mkOption {
          type = types.listOf types.str;
        };
      };
    };
  };

  kubernetes.customTypes.clusterissuer = {
    attrName = "clusterIssuers";
    group = "cert-manager.io";
    kind = "ClusterIssuer";
    version = "v1";
    module = with lib; let
      secretRefType = types.submodule (_: {
        options = {
          name = mkOption {type = types.str;};
        };
      });
    in {
      options = {
        acme = mkOption {
          type = types.submodule (_: {
            options = {
              email = mkOption {type = types.str;};
              server = mkOption {type = types.str;};
              preferredChain = mkOption {
                type = types.str;
                default = "";
              };
              privateKeySecretRef = mkOption {
                type = secretRefType;
              };
              solvers = mkOption {
                type = types.listOf (types.submodule (_: {
                  options = {
                    http01 = mkOption {
                      type = types.nullOr types.attrs;
                      default = null;
                    };
                    dns01 = mkOption {
                      type = types.nullOr types.attrs;
                      default = null;
                    };
                    selector = mkOption {
                      type = types.nullOr types.attrs;
                      default = null;
                    };
                  };
                }));
              };
            };
          });
        };
      };
    };
  };
}
