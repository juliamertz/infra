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
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [netCfg.port];

    networking.wireguard = {
      enable = true;
      interfaces.wg0 = {
        ips = ["10.100.0.6/24"];
        listenPort = netCfg.port;
        inherit (cfg) privateKeyFile;
        peers = [
          {
            publicKey = netCfg.publicKeys.julia;
            allowedIPs = ["10.100.0.1/24"];
            endpoint = "116.203.24.1:${builtins.toString netCfg.port}";
            persistentKeepalive = 25;
          }
        ];
      };
    };
  };
}
