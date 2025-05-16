{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.gateway;
in {
  options.services.gateway = with lib; {
    enable = mkEnableOption "enable the caddy proxy";

    openFirewall = mkEnableOption "Open ports 80 and 433";

    lib = mkOption {
      type = types.attrs;
      default = import ./lib.nix {inherit lib;};
    };

    domainNames = mkOption {
      type = types.listOf types.str;
      default = [];
    };

    user = mkOption {
      type = types.nonEmptyStr;
      default = "gateway";
    };

    group = mkOption {
      type = types.nonEmptyStr;
      default = "gateway";
    };

    sopsFile = mkOption {
      type = types.path;
      default = null;
    };

    extraConfig = mkOption {
      type = types.str;
      default = "";
    };

    globalConfig = mkOption {
      type = types.str;
      default = "";
    };

    stateDir = mkOption {
      type = types.path;
      default = "/var/caddy/state";
    };

    cloudflareTls = mkEnableOption "Enable cloudflare dns extension";

    services = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          subdomain = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          config = mkOption {
            type = types.nonEmptyStr;
            default = "";
          };
        };
      });
      default = {};
    };
  };

  config = {
    services.caddy = {
      enable = true;
      enableReload = true;
      inherit (cfg) user group extraConfig globalConfig;

      package =
        if cfg.cloudflareTls
        then
          pkgs.caddy.withPlugins {
            plugins = ["github.com/caddy-dns/cloudflare@v0.2.1"];
            hash = "sha256-saKJatiBZ4775IV2C5JLOmZ4BwHKFtRZan94aS5pO90=";
          }
        else pkgs.caddy;

      virtualHosts = let
        services =
          cfg.services
          |> lib.mapAttrsToList (name: value: let
            subdomain = lib.optionalString (value ? subdomain && value.subdomain != null) "${value.subdomain}.";
            mappedDomains = cfg.domainNames |> map (hostname': "${subdomain}${hostname'}");
          in
            lib.genAttrs mappedDomains (hostname: {
              extraConfig = value.config;
            }))
          |> lib.mergeAttrsList;
      in
        (lib.optionalAttrs cfg.cloudflareTls {
          "*.${cfg.hostname}".extraConfig = ''
            tls {
               dns cloudflare {env.CLOUDFLARE_API_TOKEN}
             }
          '';
        })
        // services;
    };

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [80 443];

    systemd.tmpfiles.rules = ["d ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group}"];

    users.groups.${cfg.group} = {};
    users.users.${cfg.user} = {
      inherit (cfg) group;
      isSystemUser = true;
    };

    sops = {
      secrets.cloudflare-api-token = {
        owner = cfg.user;
        sopsFile = cfg.sopsFile;
        key = "CLOUDFLARE_API_TOKEN";
      };

      templates."caddy-environment".content = ''
        HOME=${cfg.stateDir}
        CLOUDFLARE_API_TOKEN=${config.sops.placeholder.cloudflare-api-token}
      '';
    };

    systemd.services.caddy.serviceConfig = {
      EnvironmentFile = config.sops.templates."caddy-environment".path;
    };
  };
}
