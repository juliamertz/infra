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
      module = {
        options = {
          image = lib.mkOption {
            type = lib.types.str;
          };
          imagePullPolicy = lib.mkOption {
            type = lib.types.str;
            default = "IfNotPresent";
          };
          replicas = lib.mkOption {
            type = lib.types.int;
            default = 1;
          };
          resources = lib.mkOption {
            type = lib.types.attrs;
            default = {};
          };
        };
      };
    };
  };
}
