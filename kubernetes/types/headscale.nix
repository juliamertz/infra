{
  kubenix,
  lib,
  ...
}: {
  imports = [kubenix.modules.k8s];

  kubernetes.customTypesModuleDefinesCRDSpec = true;

  kubernetes.customTypes = {
    headscale = {
      attrName = "headscales";
      group = "headscale.juliamertz.dev";
      kind = "Headscale";
      version = "v1alpha1";
      module = with lib; {
        options = {
          tls = mkOption {
            type = types.nullOr types.attrs;
            default = null;
          };
          config = mkOption {
            type = types.attrs;
          };
          deployment = mkOption {
            type = types.nullOr types.attrs;
            default = null;
          };
        };
      };
    };

    headscalepolicy = {
      attrName = "headscalePolicies";
      group = "headscale.juliamertz.dev";
      kind = "Policy";
      version = "v1alpha1";
      module = with lib; {
        options = {
          headscaleRef = mkOption {type = types.attrs;};
          acls = mkOption {type = types.listOf types.attrs;};
        };
      };
    };

    headscaleuser = {
      attrName = "headscaleUsers";
      group = "headscale.juliamertz.dev";
      kind = "User";
      version = "v1alpha1";
      module = with lib; {
        options = {
          headscaleRef = mkOption {type = types.attrs;};
        };
      };
    };

    headscalepreauthkey = {
      attrName = "headscalePreauthKeys";
      group = "headscale.juliamertz.dev";
      kind = "PreauthKey";
      version = "v1alpha1";
      module = with lib; {
        options = {
          ephemeral = mkOption {
            type = types.bool;
            default = false;
          };
          reusable = mkOption {
            type = types.bool;
            default = false;
          };
          expiration = mkOption {type = types.str;};
          targetSecret = mkOption {type = types.str;};
          user = mkOption {type = types.attrs;};
        };
      };
    };
  };
}
