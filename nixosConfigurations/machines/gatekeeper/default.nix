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

  gateway = with config.gateway.lib; let
    auth = basicAuth "$2a$14$5ELp7zhUeAS8PEGotSNUvO94demOSE.pGPuQfEfXwQ8kqp0wx42Q6";
  in {
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

  imports = [
    ../../modules/gateway
  ];
}
