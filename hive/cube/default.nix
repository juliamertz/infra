{
  inputs,
  name,
  nodes,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ../../nixosModules/minecraft
    ../../nixosModules/monitoring/system
    ../../nixosModules/monitoring/logs
  ];

  networking.hostName = name;

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "mcdo" ''
      echo "$@" > /run/minecraft/fabric.stdin
    '')
  ];

  services.minecraft-servers = {
    enable = true;
    openFirewall = true;

    servers.fabric = {
      enable = true;
      jvmOpts = "-Xmx14G -Xms14G";
      package = pkgs.fabricServers.fabric-1_20_1.override {loaderVersion = "0.16.10";};

      symlinks = {
        mods = let
          modpack = pkgs.fetchPackwizModpack {
            url = "http://github.com/juliamertz/pack/raw/0.0.12/pack.toml";
            packHash = "sha256-hiruONtkWskexQL3q2qeJiuP8mDr6cI0eRLgRZHCCRs=";
          };
        in "${modpack}/mods";
      };

      serverProperties = {
        gamemode = 0;
        difficulty = 2;
        max-players = 10;
        white-list = true;
        motd = "NixOS Minecraft server!";
      };
    };
  };

  services.monitoring.system = {
    enable = true;
    units = ["minecraft-server-fabric"];
  };

  services.monitoring.logs = {
    enable = true;

    endpoint = let
      host = "10.0.1.3";
      port = toString nodes.topdog.config.services.loki.configuration.server.http_listen_port;
    in "http://${host}:${port}/loki/api/v1/push";

    units = ["minecraft-server-fabric"];
  };

  # fileSystems. "/data" = {
  #   device = "/dev/sdb";
  #   fsType = "ext4";
  #   options = ["data=journal"];
  # };
}
