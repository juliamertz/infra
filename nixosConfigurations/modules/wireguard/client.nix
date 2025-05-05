{...}: let
  netCfg = import ./network.nix;
in {
  networking.firewall.allowedUDPPorts = [netCfg.port];
  networking.wireguard = {
    enable = true;
    interfaces = {
      wg0 = {
        ips = ["10.100.0.6/24"];
        listenPort = netCfg.port;
        privateKeyFile = "/etc/wireguard/private";

        peers = [
          {
            publicKey = netCfg.publicKeys.julia;
            allowedIPs = ["10.100.0.0/24"];
            endpoint = "167.235.129.122:${builtins.toString netCfg.port}";
            persistentKeepalive = 25;
          }
        ];
      };
    };
  };
}
