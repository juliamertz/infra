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

    internalInterface = mkOption {
      type = types.str;
      default = "wg0";
    };

    externalInterface = mkOption {
      type = types.str;
      default = "eth0";
    };

    ipRange = mkOption {
      type = types.str;
      default = "10.100.0.1/24";
    };

    enableForwarding = mkEnableOption ''
      Enable ipv4 forwarding,
      this makes the server act as a router between peers
    '';
  };

  config = lib.mkIf cfg.enable {
    networking.nat = {
      enable = true;
      inherit (cfg) externalInterface;
      internalInterfaces = [cfg.internalInterface];
    };

    networking.firewall = {
      allowedUDPPorts = [netCfg.port];
      trustedInterfaces = [cfg.internalInterface];
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = cfg.enableForwarding;
    };

    networking.wireguard = {
      enable = true;
      interfaces.${cfg.internalInterface} = {
        ips = [cfg.ipRange];
        listenPort = netCfg.port;
        privateKeyFile = cfg.privateKeyFile;
        peers = lib.mapAttrsToList (k: v: v) netCfg.peers;
      };
    };
  };
}
