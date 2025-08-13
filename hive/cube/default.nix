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

      package = servers.neoforgeServers.neoforge-21_1_193;

      symlinks = {
        mods = let
          serverMods = pkgs.linkFarmFromDrvs "mods" (
            builtins.attrValues {
              kubejs = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/umyGl7zF/versions/3w2ufpfQ/kubejs-neoforge-2101.7.1-build.181.jar";
                sha256 = "sha256-fh4RaGODxfHZuGn/SKSFhzUG5PLXgz3nPSNroLVyuu0=";
              };
            }
          );

          modpack = pkgs.fetchPackwizModpack {
            url = "http://github.com/juliamertz/pack/raw/neoforge-beta-0.0.1/pack.toml";
            packHash = "sha256-bcFH0zOcVqAZggZNJHdsUwtl9Fvj69mlm1uINuTiETY=";
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
        motd = "NixOS NeoForge server!";
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
