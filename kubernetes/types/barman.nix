{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes.objectstore = {
    attrName = "objectStores";
    group = "barmancloud.cnpg.io";
    kind = "ObjectStore";
    version = "v1";
    module = with lib; {
      options = {
        retentionPolicy = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        configuration = mkOption {type = types.attrs;};
      };
    };
  };
}
