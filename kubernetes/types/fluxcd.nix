{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes = {
    gitrepository = {
      attrName = "gitRepositories";
      group = "source.toolkit.fluxcd.io";
      kind = "GitRepository";
      version = "v1";
      module = with lib; {
        options = {
          interval = mkOption {
            type = types.str;
            default = "5m0s";
          };
          url = mkOption {
            type = types.str;
          };
          ref = mkOption {
            type = types.nullOr types.attrs;
            default = null;
          };
        };
      };
    };

    helmrepository = {
      attrName = "helmRepositories";
      group = "source.toolkit.fluxcd.io";
      kind = "HelmRepository";
      version = "v1";
      module = with lib; {
        options = {
          interval = mkOption {
            type = types.str;
            default = "30m";
          };
          type = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          url = mkOption {
            type = types.str;
          };
        };
      };
    };

    helmrelease = {
      attrName = "helmReleases";
      group = "helm.toolkit.fluxcd.io";
      kind = "HelmRelease";
      version = "v2";
      module = with lib; let
        sourceRefType = types.submodule (_: {
          options = {
            kind = mkOption {type = types.str;};
            name = mkOption {type = types.str;};
          };
        });
        chartSpecType = types.submodule (_: {
          options = {
            chart = mkOption {
              description = "Chart name";
              type = types.str;
            };
            version = mkOption {
              description = "Chart version";
              type = types.str;
            };
            interval = mkOption {
              description = "Chart refresh interval";
              type = types.str;
              default = "30m";
            };
            reconcileStrategy = mkOption {
              type = types.str;
              default = "ChartVersion";
            };
            sourceRef = mkOption {
              type = sourceRefType;
            };
          };
        });
      in {
        options = {
          chart = mkOption {
            description = "Chart config";
            type = types.submodule (_: {
              options = {
                spec = mkOption {
                  description = "Chart spec";
                  type = chartSpecType;
                };
              };
            });
          };
          values = mkOption {
            description = "Chart values";
            type = types.attrs;
          };
          interval = mkOption {
            type = types.str;
            default = "30m";
          };
          install = mkOption {
            type = types.nullOr types.attrs;
            default = null;
          };
          upgrade = mkOption {
            type = types.nullOr types.attrs;
            default = null;
          };
        };
      };
    };
  };
}
