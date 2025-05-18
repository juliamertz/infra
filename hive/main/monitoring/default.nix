{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./loki.nix
    ./alloy.nix
  ];

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

      dashboards.settings.providers = [
        {
          name = "My dashboards";
          options.path = ./dashboards;
        }
      ];

      # datasources.settings.deleteDatasources = [ { name = "Prometheus"; orgId = 1; } ];

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

    scrapeConfigs = let
      mkExporter = name: {
        job_name = "${name}_exporter";
        static_configs = [
          {targets = ["0.0.0.0:${toString config.services.prometheus.exporters.${name}.port}"];}
        ];
      };
    in
      (map mkExporter [
        "systemd"
        "process"
        "node"
      ])
      ++ [
        {
          job_name = "nettenshop_exporter";
          static_configs = [{targets = ["0.0.0.0:5010"];}];
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
}
