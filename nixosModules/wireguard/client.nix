{
  lib,
  config,
  ...
}: let
  cfg = config.services.wireguard-client;
in {
  options.services.wireguard-client = with lib; {
    enable = mkEnableOption "Wireguard client";

    privateKeyFile = mkOption {
      type = types.path;
      default = "/etc/wireguard/keys/private";
    };

    internalInterface = mkOption {
      type = types.str;
      default = "wg0";
    };

    ipRange = mkOption {
      type = types.str;
    };

    serverIp = mkOption {
      type = types.str;
    };

    net = mkOption {
      type = types.attrs;
      default = import ./network.nix;
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      allowedUDPPorts = [cfg.net.port];
      trustedInterfaces = [cfg.internalInterface];
    };

    networking.wireguard = {
      enable = true;
      interfaces.${cfg.internalInterface} = {
        ips = [cfg.ipRange];
        listenPort = cfg.net.port;
        inherit (cfg) privateKeyFile;
        peers = [
          {
            publicKey = cfg.net.server.publicKey;
            allowedIPs = [cfg.net.server.ipRange];
            endpoint = "${cfg.serverIp}:${builtins.toString cfg.net.port}";
            persistentKeepalive = 25;
          }
        ];
      };
    };
  };
}
