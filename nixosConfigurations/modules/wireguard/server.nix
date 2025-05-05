{
  lib,
  config,
  ...
}: let
  cfg = config.wireguard;
  netCfg = import ./network.nix;
in {
  options.wireguard = with lib; {
    ipRange = mkOption {
      type = types.str;
      default = "10.100.0.1/24";
    };
  };

  config = {
    networking.nat.enable = true;
    networking.nat.externalInterface = "enp1s0";
    networking.nat.internalInterfaces = ["wg0"];
    networking.firewall.allowedUDPPorts = [netCfg.port];

    networking.wireguard.enable = true;
    networking.wireguard.interfaces = {
      wg0 = {
        ips = [cfg.ipRange];
        listenPort = cfg.port;
        privateKeyFile = "/etc/wireguard/private";
        peers = lib.mapAttrsToList (k: v: v) netCfg.peers;
      };
    };
  };
}
