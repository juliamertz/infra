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

    services = with config.services.gateway.lib; {
      github = {
        subdomain = "gh";
        config = redirect "https://github.com/juliamertz";
      };

      nettenshop = {
        subdomain = "nettenshop";
        config = ''
          respond /metrics "Unauthorized." 401

          reverse_proxy http://10.0.1.2:5010
        '';
      };

      grafana = {
        subdomain = "grafana";
        config = ''
          reverse_proxy http://10.0.1.2:3000
        '';
      };

      cache = {
        subdomain = "cache";
        config = ''
          reverse_proxy http://10.0.1.2:7678
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
