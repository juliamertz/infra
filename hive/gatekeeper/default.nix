{
  name,
  nodes,
  pkgs,
  config,
  ...
}: {
  networking.hostName = name;

  sops.age.keyFile = "/etc/sops/age/keys.txt";

  networking.firewall.allowedTCPPorts = [22];

  services.gateway = {
    enable = true;
    openFirewall = true;

    domainNames = [
      "juliamertz.nl"
      "juliamertz.dev"
    ];

    sopsFile = ../../secrets/gateway.yaml;

    globalConfig = ''
      persist_config off
    '';

    services = let
      inherit (config.services.wireguard-server) net;
    in
      with config.services.gateway.lib; {
        github = {
          subdomain = "gh";
          config = redirect "https://github.com/juliamertz";
        };

        nettenshop = {
          subdomain = "nettenshop";
          config = ''
            respond /metrics "Unauthorized." 401

            reverse_proxy http://${net.peers.topdog.subnetIp}:5010
          '';
        };

        grafana = {
          subdomain = "grafana";
          config = ''
            reverse_proxy http://${net.peers.topdog.subnetIp}:3000
          '';
        };

        cache = {
          subdomain = "cache";
          config = ''
            reverse_proxy http://${net.peers.topdog.subnetIp}:7678
          '';
        };

        jellyfin = {
          subdomain = "watch";
          config = ''
            reverse_proxy http://${net.peers.homelab.subnetIp}:8096
          '';
        };

        home-assistant = {
          subdomain = "home-assistant";
          config = ''
            reverse_proxy http://${net.peers.homelab.subnetIp}:8123
          '';
        };
      };
  };

  sops.secrets.wireguardPrivateKey = {
    key = name;
    owner = "julia";
    sopsFile = ../../secrets/wireguard.yaml;
  };

  services.wireguard-server = {
    enable = true;
    enableForwarding = true;
    privateKeyFile = config.sops.secrets.wireguardPrivateKey.path;
    externalInterface = "eth0";
  };

  imports = [
    ../../nixosModules/gateway
    ../../nixosModules/wireguard
  ];
}
