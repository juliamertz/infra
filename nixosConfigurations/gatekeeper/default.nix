{
  config,
  ...
}: {
  networking = {
    hostName = "gatekeeper";

    interfaces.enp7s0.useDHCP = true;

    firewall = {
      allowedTCPPorts = [80 443];
      trustedInterfaces = ["enp7s0"];
    };
  };

  gateway = with config.gateway.lib; {
    hostname = "juliamertz.dev";

    services = {
      website = {
        config = redirect "https://github.com/juliamertz";
      };

      github = {
        subdomain = "gh";
        config = redirect "https://github.com/juliamertz";
      };

      nettenshop = {
        subdomain = "nettenshop-staging";
        config = reverseProxy {
          address = "http://10.0.1.2:5010";
          copyResponseHeaders = true;
        };
      };

      # jellyfin = {
      #   subdomain = "watch";
      #   config = lib.reverseProxy {
      #     address = "http://${hosts.hydra.internal}:8096";
      #     copyResponseHeaders = true;
      #   };
      # };
    };
  };

  imports = [
    ./modules/gateway
  ];
}
