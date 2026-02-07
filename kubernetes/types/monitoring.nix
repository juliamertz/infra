{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes = {
    servicemonitor = {
      attrName = "serviceMonitors";
      group = "monitoring.coreos.com";
      kind = "ServiceMonitor";
      version = "v1";
      module = with lib; {
        options = {
          endpoints = mkOption {type = types.listOf types.attrs;};
          namespaceSelector = mkOption {
            type = types.nullOr types.attrs;
            default = null;
          };
          selector = mkOption {type = types.attrs;};
        };
      };
    };

    podmonitor = {
      attrName = "podMonitors";
      group = "monitoring.coreos.com";
      kind = "PodMonitor";
      version = "v1";
      module = with lib; {
        options = {
          podMetricsEndpoints = mkOption {type = types.listOf types.attrs;};
          selector = mkOption {type = types.attrs;};
        };
      };
    };

    probe = {
      attrName = "probes";
      group = "monitoring.coreos.com";
      kind = "Probe";
      version = "v1";
      module = with lib; {
        options = {
          interval = mkOption {
            type = types.str;
            default = "30s";
          };
          module = mkOption {type = types.str;};
          prober = mkOption {type = types.attrs;};
          targets = mkOption {type = types.attrs;};
        };
      };
    };
  };
}
