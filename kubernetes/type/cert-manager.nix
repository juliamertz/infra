{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.clusterissuer = {
    attrName = "clusterissuers";
    group = "cert-manager.io";
    kind = "ClusterIssuer";
    version = "v1";
    module = {
      options = {
        acme = lib.mkOption {
          type = lib.types.attrs;
        };
      };
    };
  };
}
