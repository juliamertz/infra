{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes.cnpgcluster = {
    attrName = "cnpgClusters";
    group = "postgresql.cnpg.io";
    kind = "Cluster";
    version = "v1";
    module = with lib; {
      options = {
        instances = mkOption {
          type = types.int;
          default = 1;
        };
        primaryUpdateStrategy = mkOption {
          type = types.str;
          default = "unsupervised";
        };
        primaryUpdateMethod = mkOption {
          type = types.str;
          default = "switchover";
        };
        enableSuperuserAccess = mkOption {
          type = types.bool;
          default = false;
        };
        storage = mkOption {
          type = types.submodule (_: {
            options = {
              size = mkOption {type = types.str;};
              storageClass = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              resizeInUseVolumes = mkOption {
                type = types.nullOr types.bool;
                default = null;
              };
            };
          });
        };
      };
    };
  };
}
