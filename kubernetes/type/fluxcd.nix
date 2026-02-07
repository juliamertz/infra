{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes = {
    helmrepository = {
      attrName = "helmRepositories";
      group = "source.toolkit.fluxcd.io";
      kind = "HelmRepository";
      version = "v1";
      module = {
        options = {
          interval = lib.mkOption {
            type = lib.types.str;
            default = "30m";
          };
          type = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          url = lib.mkOption {
            type = lib.types.str;
          };
        };
      };
    };

    helmrelease = {
      attrName = "helmReleases";
      group = "helm.toolkit.fluxcd.io";
      kind = "HelmRelease";
      version = "v2";
      module = {
        options = {
          chart = lib.mkOption {
            description = "Chart config";
            type = lib.types.attrs;
          };
          values = lib.mkOption {
            description = "Chart values";
            type = lib.types.attrs;
          };
          interval = lib.mkOption {
            type = lib.types.str;
            default = "30m";
          };
          install = lib.mkOption {
            type = lib.types.nullOr lib.types.attrs;
            default = null;
          };
          upgrade = lib.mkOption {
            type = lib.types.nullOr lib.types.attrs;
            default = null;
          };
        };
      };
    };
  };
}
