{config, ...}: {
  networking = {
    hostName = "gatekeeper";

    interfaces.eth0 = {
      ipv4.addresses = [
        # floating ip
        # TODO: don't hardcode this
        {
          address = "116.202.187.106";
          prefixLength = 32;
        }
        {
          address = "91.99.65.167";
          prefixLength = 32;
        }
      ];
    };
  };

  services.gateway = with config.services.gateway.lib; {
    hostname = "staging.juliamertz.dev";

    services = {
      github = {
        subdomain = "gh";
        config = redirect "https://github.com/juliamertz";
      };

      nettenshop = {
        subdomain = "nettenshop";
        config = reverseProxy "http://10.0.1.2:5010";
      };

      # home-assistant = {
      #   subdomain = "home-assistant";
      #   config = auth (reverseProxy "http://10.0.1.1:5010");
      # };
    };
  };

  services.wireguard-server = {
    enable = true;
    enableForwarding = true;
    privateKeyFile = "/etc/wireguard/keys/private";
    externalInterface = "eth0";
  };

  imports = [
    ../../modules/gateway
    ../../modules/wireguard
  ];
}
