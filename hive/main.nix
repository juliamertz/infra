{
  name,
  nodes,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ../nixosModules/nettenshop
    ../nixosModules/wireguard
  ];

  deployment = {
    targetHost = "91.99.65.167";
    # targetHost = name;
    targetUser = "root";
    targetPort = 22;
  };

  networking.hostName = name;

  sops.age.keyFile = "/etc/sops/age/keys.txt";

  services.nettenshop = {
    enable = true;
    openFirewall = true;
    sopsFile = ../secrets/nettenshop.yaml;
    extraUsers = ["julia"];
  };

  sops.secrets.wireguardPrivateKey = {
    key = name;
    owner = "julia";
    sopsFile = ../secrets/wireguard.yaml;
  };

  services.wireguard-client = {
    enable = true;
    ipRange = "10.100.0.2/24";
    serverIp = "10.0.1.1";
    privateKeyFile = config.sops.secrets.wireguardPrivateKey.path;
  };

  networking.firewall.allowedTCPPorts = [3000];

  services.grafana = {
    enable = false;
    settings = {
      server = {
        http_port = 3000;
        http_addr = "0.0.0.0";
      };
    };
  };

  services.prometheus = {
    enable = false;
    port = 9090;

    scrapeConfigs = with config.services.prometheus; [
      {
        job_name = "systemd_exporter";
        static_configs = [
          {targets = ["0.0.0.0:${toString exporters.systemd.port}"];}
        ];
      }
    ];

    exporters = {
      systemd = let
        monitoredUnits = with config; [
          services.nettenshop.serviceName
        ];
      in {
        enable = true;
        extraFlags = [
          "--systemd.collector.enable-restart-count"
          "--systemd.collector.enable-ip-accounting"
          "--systemd.collector.unit-include=${monitoredUnits |> map (v: v + ".service") |> lib.concatStringsSep "|"}"
        ];
      };

      # process = {
      #   enable = true;
      #   settings = {
      #     # process_names = [
      #     #   "lightspeed-dhl"
      #     #   "grafana"
      #     #   {
      #     #     name = "{{.Matches.Wrapped}} {{ .Matches.Args }}";
      #     #     cmdline = ["^/nix/store[^ ]*/(?P<Wrapped>[^ /]*) (?P<Args>.*)"];
      #     #   }
      #     # ];
      #   };
      # };
    };
  };
}
