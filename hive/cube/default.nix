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

  services.minecraft-servers = let
    servers = import "${inputs.nix-minecraft}/pkgs/all-packages.nix" pkgs;
  in {
    enable = true;
    openFirewall = true;

    servers.fabric = {
      enable = true;
      jvmOpts = "-Xmx14G -Xms14G";

      # package = servers.neoforgeServers.neoforge-21_1_193;
      package = pkgs.fabricServers.fabric-1_20_1.override {loaderVersion = "0.17.0";};

      symlinks = {
        mods = let
          serverMods = pkgs.linkFarmFromDrvs "mods" (
            builtins.attrValues {
              fabric-api = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/UapVHwiP/fabric-api-0.92.6%2B1.20.1.jar";
                sha256 = "sha256-Ds5QR22jaSERqwS3WUXFRY5w2YzQae78BEqz5Xl33us=";
              };
              fabric-exporter = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/dbVXHSlv/versions/5sFtYOmu/fabricexporter-1.0.14.jar";
                sha256 = "sha256-7Uor+Fq3qDBX+G4Q5PZY4Y2PlKeLu1fWTtvottrj6ac=";
              };
              spark = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/l6YH9Als/versions/XGW2fviP/spark-1.10.53-fabric.jar";
                sha256 = "sha256-AMA05oT6RHG0FTncKajTnMbyLrKbL6QjiV78l4o5HS0=";
              };
              multiworld = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/fgvoNDL1/versions/vsVkTQvL/Multiworld-Fabric-bundle.jar";
                sha256 = "sha256-abBXgL3sRN3RdKNlnDQs8k9TgAlA9KU8bcEDYB57Z20=";
              };
            }
          );

          modpack = pkgs.fetchPackwizModpack {
            url = "http://github.com/juliamertz/pack/raw/0.3.0/pack.toml";
            packHash = "sha256-i/qJ5+7iebpTL2UiFachYUdloOpTHBPhsqdgvlCaKZw=";

            # url = "http://github.com/juliamertz/pack/raw/neoforge-beta-0.0.1/pack.toml";
            # packHash = "sha256-bcFH0zOcVqAZggZNJHdsUwtl9Fvj69mlm1uINuTiETY=";
          };
        in
          pkgs.symlinkJoin {
            name = "mods";
            paths = [
              serverMods
              "${modpack}/mods"
            ];
          };
      };

      serverProperties = {
        gamemode = 0;
        difficulty = 2;
        max-players = 10;
        white-list = true;
        motd = "NixOS Fabric server!";
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

  networking.firewall.allowedTCPPorts = [
    8123 # dynmap
  ];

  # fileSystems. "/data" = {
  #   device = "/dev/sdb";
  #   fsType = "ext4";
  #   options = ["data=journal"];
  # };
}
