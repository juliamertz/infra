{
  nodes,
  pkgs,
  ...
}: {
  imports = [
    ../../nixosModules/minecraft
    ../../nixosModules/monitoring/system
    ../../nixosModules/monitoring/logs
  ];

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

      package = pkgs.neoforgeServers.neoforge-21_1_200;

      symlinks = {
        mods = let
          serverMods = pkgs.linkFarmFromDrvs "mods" (
            builtins.attrValues { }
          );

          modpack = pkgs.fetchPackwizModpack {
            url = "http://github.com/juliamertz/pack/raw/0.5.1/pack.toml";
            packHash = "sha256-iSlDClRiOcYBW5fG84ccMcG46ZuZ2HxvZIt2gXk2JX0=";
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
        allow-flight = true;
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
