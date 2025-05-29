{
  lib,
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
      inherit (config.services.wireguard-server.net) peers;
    in
      with config.services.gateway.lib; {
        github = {
          subdomain = "gh";
          config = redirect "https://github.com/juliamertz";
        };

        nettenshop = {
          subdomain = "nettenshop";
          config = reverseProxy {
            host = peers.topdog.subnetIp;
            port = nodes.topdog.config.services.nettenshop.port;
            blockedRoutes = ["/metrics"];
          };
        };

        grafana = {
          subdomain = "grafana";
          config = reverseProxy {
            host = peers.topdog.subnetIp;
            port = nodes.topdog.config.services.grafana.settings.server.http_port;
          };
        };

        cache = {
          subdomain = "cache";
          config = reverseProxy {
            host = peers.topdog.subnetIp;
            port = 7678;
          };
        };

        jellyfin = {
          subdomain = "watch";
          config = reverseProxy {
            host = peers.homelab.subnetIp;
            port = 8096;
          };
        };

        home-assistant = {
          subdomain = "home-assistant";
          config = reverseProxy {
            host = peers.homelab.subnetIp;
            port = 8123;
          };
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
