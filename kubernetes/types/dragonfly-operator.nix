{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes = {
    dragonfly = {
      attrName = "dragonflies";
      group = "dragonflydb.io";
      kind = "Dragonfly";
      version = "v1alpha1";
      module = with lib; let
        resourceQuantityType = types.submodule (_: {
          options = {
            memory = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            cpu = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
          };
        });
      in {
        options = {
          image = mkOption {
            type = types.str;
          };
          imagePullPolicy = mkOption {
            type = types.str;
            default = "IfNotPresent";
          };
          replicas = mkOption {
            type = types.int;
            default = 1;
          };
          resources = mkOption {
            type = types.submodule (_: {
              options = {
                requests = mkOption {
                  type = types.nullOr resourceQuantityType;
                  default = null;
                };
                limits = mkOption {
                  type = types.nullOr resourceQuantityType;
                  default = null;
                };
              };
            });
            default = {};
          };
        };
      };
    };
  };
}
