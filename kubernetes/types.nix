{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes = {
    helmrepository = {
      attrName = "helmrepositories";
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
      attrName = "helmreleases";
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
    clusterissuer = {
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

    storageclass = {
      attrName = "storageclasses";
      group = "storage.k8s.io";
      kind = "StorageClass";
      version = "v1";
      module = {
        options = {
          provisioner = lib.mkOption {
            type = lib.types.str;
          };
          allowVolumeExpansion = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          parameters = lib.mkOption {
            type = lib.types.attrs;
            default = {};
          };
        };
      };
    };

    gatewayclass = {
      attrName = "gatewayclasses";
      group = "gateway.networking.k8s.io";
      kind = "GatewayClass";
      version = "v1";
      module = {
        options = {
          controllerName = lib.mkOption {
            type = lib.types.str;
          };
          parametersRef = lib.mkOption {
            type = lib.types.nullOr lib.types.attrs;
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
      module = {
        options = {
          provider = lib.mkOption {
            type = lib.types.attrs;
          };
        };
      };
    };

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
