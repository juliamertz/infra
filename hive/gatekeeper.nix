{
  name,
  nodes,
  pkgs,
  config,
  ...
}: let
  floatingIp = "116.202.187.106";
in {
  networking.hostName = name;

  deployment = {
    targetHost = "116.203.24.1";
    # targetHost = name;
    targetUser = "root";
    targetPort = 22;
  };

  sops.age.keyFile = "/etc/sops/age/keys.txt";

  networking.interfaces.eth0 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        # public ip
        address = "116.203.24.1";
        prefixLength = 24;
      }
      # { # floating ip
      #   address = floatingIp;
      #   prefixLength = 32;
      # }
    ];
  };

  # TODO: figure out why this hack is neccesarry
  systemd.services.add-floating-ip = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ["${pkgs.iproute2}/bin/ip addr add ${floatingIp}/32 dev eth0"];
      RemainAfterExit = true;
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
    };
  };

  sops.secrets.wireguardPrivateKey = {
    key = name;
    owner = "julia";
    sopsFile = ../secrets/wireguard.yaml;
  };

  services.wireguard-server = {
    enable = true;
    enableForwarding = true;
    privateKeyFile = config.sops.secrets.wireguardPrivateKey.path;
    externalInterface = "eth0";
  };

  imports = [
    ../nixosModules/gateway
    ../nixosModules/wireguard
  ];
}
