{
  lib,
  config,
  ...
}: let
  netCfg = import ./network.nix;
  cfg = config.services.wireguard-client;
in {
  options.services.wireguard-client = with lib; {
    enable = mkEnableOption "Wireguard client";

    privateKeyFile = mkOption {
      type = types.path;
      default = "/etc/wireguard/keys/private";
    };

    ipRange = mkOption {
      type = types.str;
    };

    serverIp = mkOption {
      type = types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [netCfg.port];

    networking.wireguard = {
      enable = true;
      interfaces.wg0 = {
        ips = [cfg.ipRange];
        listenPort = netCfg.port;
        inherit (cfg) privateKeyFile;
        peers = [
          {
            publicKey = netCfg.server.publicKey;
            allowedIPs = [netCfg.server.ipRange];
            endpoint = "${cfg.serverIp}:${builtins.toString netCfg.port}";
            persistentKeepalive = 25;
          }
        ];
      };
    };
  };
}
