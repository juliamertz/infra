{
  lib,
  config,
  ...
}: let
  cfg = config.services.wireguard-server;
  netCfg = import ./network.nix;
in {
  options.services.wireguard-server = with lib; {
    enable = mkEnableOption "Wireguard server";

    privateKeyFile = mkOption {
      type = types.path;
      default = "/etc/wireguard/keys/private";
    };

    externalInterface = mkOption {
      type = types.str;
      default = "eth0";
    };

    ipRange = mkOption {
      type = types.str;
      default = "10.100.0.1/24";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.nat = {
      enable = true;
      inherit (cfg) externalInterface;
      internalInterfaces = ["wg0"];
    };

    networking.firewall.allowedUDPPorts = [netCfg.port];

    networking.wireguard = {
      enable = true;
      interfaces.wg0 = {
        ips = [cfg.ipRange];
        listenPort = netCfg.port;
        privateKeyFile = cfg.privateKeyFile;
        peers = lib.mapAttrsToList (k: v: v) netCfg.peers;
      };
    };
  };
}
