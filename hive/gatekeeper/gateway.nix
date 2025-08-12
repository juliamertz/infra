{
  nodes,
  config,
  ...
}: {
  imports = [../../nixosModules/gateway];

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

        dynmap = {
          subdomain = "dynmap";
          # config = reverseProxy {
          #   host = "10.0.1.4";
          #   port = 8123;
          # };
          config = ''
            reverse_proxy 10.0.1.4:8123 {
              header_up Host {host}
              header_up X-Real-IP {remote}
              header_up X-Forwarded-For {remote}
            }
          '';
        };
      };
  };
}
