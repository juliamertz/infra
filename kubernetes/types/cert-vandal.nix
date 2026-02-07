{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes.saninjection = {
    attrName = "sanInjections";
    group = "cert-vandal.io";
    kind = "SANInjection";
    version = "v1";
    module = with lib; {
      options = {
        targetCertificate = mkOption {
          type = types.submodule (_: {
            options = {
              name = mkOption {type = types.str;};
              namespace = mkOption {type = types.str;};
            };
          });
        };
        hostnames = mkOption {
          type = types.listOf types.str;
        };
      };
    };
  };
}
