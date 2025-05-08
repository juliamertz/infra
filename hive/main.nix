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
    targetHost = name;
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

  services.wireguard-client = {
    enable = true;
    ipRange = "10.100.0.2/24";
    serverIp = "10.0.1.1";
  };

  networking.firewall.allowedTCPPorts = [3000 9090];

  # services.grafana = {
  #   enable = true;
  #   settings = {
  #     server = {
  #       http_addr = "0.0.0.0";
  #       http_port = 3000;
  #       # domain = "your.domain";
  #       # root_url = "https://your.domain/grafana/";
  #       # serve_from_sub_path = true;
  #     };
  #   };
  # };
  #
  # services.prometheus = {
  #   enable = true;
  #   port = 9090;
  #
  #   scrapeConfigs = [
  #     {
  #       job_name = "systemd_exporter";
  #       static_configs = [
  #         {
  #           targets = ["0.0.0.0:${toString config.services.prometheus.exporters.systemd.port}"];
  #         }
  #       ];
  #     }
  #   ];
  #
  #   exporters.systemd = let
  #     monitoredUnits = map (v: v + ".service") [
  #       config.services.nettenshop.serviceName
  #     ];
  #   in {
  #     enable = true;
  #     openFirewall = true;
  #     extraFlags = [
  #       "--systemd.collector.enable-restart-count"
  #       "--systemd.collector.enable-ip-accounting"
  #       "--systemd.collector.unit-include=${lib.concatStringsSep "|" monitoredUnits}"
  #       # "--systemd.collector.unit-exclude=.*"
  #     ];
  #   };
  # };
}
