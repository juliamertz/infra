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
    ../nixosModules/cache
  ];

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
    enable = true;
    settings = {
      server = {
        http_port = 3000;
        http_addr = "0.0.0.0";
      };
    };

    declarativePlugins = with pkgs.grafanaPlugins; [];

    provision = {
      enable = true;

      # dashboards.settings.providers = [
      #   {
      #     name = "my dashboards";
      #     options.path = "/etc/grafana-dashboards";
      #   }
      # ];

      datasources.settings.datasources = with config.services.prometheus; [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:${toString port}";
        }
      ];
    };
  };

  services.prometheus = {
    enable = true;
    port = 9090;

    scrapeConfigs = with config.services.prometheus; let
      mkExporter = name: {
        job_name = "${name}_exporter";
        static_configs = [{targets = ["0.0.0.0:${toString exporters.${name}.port}"];}];
      };
    in
      map mkExporter [
        "systemd"
        "process"
        "node"
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

      process = {
        enable = true;
        settings.process_names = [
          # Remove nix store path from process name
          {
            name = "{{.Matches.Wrapped}} {{ .Matches.Args }}";
            cmdline = ["^/nix/store[^ ]*/(?P<Wrapped>[^ /]*) (?P<Args>.*)"];
          }
        ];
      };

      node = {
        enable = true;
        enabledCollectors = ["logind" "systemd"];
      };
    };
  };

  services.cache = {
    enable = true;
    openFirewall = true;
    sopsFile = ../secrets/attic.env;
  };
}
