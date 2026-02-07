{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes = {
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
  };
}
