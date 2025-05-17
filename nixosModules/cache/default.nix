{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.cache;
in {
  options.services.cache = with lib; {
    enable = mkEnableOption "Attic cache";

    openFirewall = mkEnableOption "firewall";

    package = mkOption {
      type = types.package;
      default = pkgs.attic-server;
    };

    port = mkOption {
      type = types.port;
      default = 7678;
    };

    sopsFile = mkOption {
      type = types.path;
      default = null;
    };

    user = mkOption {
      type = types.str;
      default = "attic";
    };

    group = mkOption {
      type = types.str;
      default = "attic";
    };
  };

  config = {
    sops.secrets.attic-environment = {
      owner = cfg.user;
      format = "dotenv";
      sopsFile = cfg.sopsFile;
    };

    services.atticd = {
      enable = true;

      inherit (cfg) user group;

      environmentFile = config.sops.secrets."attic-environment".path;

      settings = {
        listen = "[::]:${toString cfg.port}";

        allowed-hosts = ["cache.juliamertz.nl"];

        api-endpoint = "https://cache.juliamertz.nl/";

        chunking = {
          nar-size-threshold = 64 * 1024;
          min-size = 16 * 1024;
          avg-size = 64 * 1024;
          max-size = 256 * 1024;
        };

        jwt = {};
      };
    };

    users.groups.${cfg.group} = {};
    users.users.${cfg.user} = {
      inherit (cfg) group;
      isSystemUser = true;
    };
  };
}
