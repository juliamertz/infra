{
  lib,
  config,
  kubenix,
  crds,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = {
    namespace = "minecraft";

    resources.namespaces.minecraft = {};

    resources.persistentVolumeClaims.minecraft.spec = {
      storageClassName = "hcloud-volumes";
      accessModes = ["ReadWriteOnce"];
      resources.requests.storage = "10Gi";
    };

    resources.helmRepositories.itzg.spec = {
      url = "https://itzg.github.io/minecraft-server-charts";
    };

    resources.secrets.rcon-credentials.stringData = lib.mapAttrs (_: path: "ref+sops://secrets/kubenix.yaml#${path}") {
      username = "/minecraft/rcon/username";
      password = "/minecraft/rcon/password";
    };

    resources.helmReleases.minecraft.spec = {
      chart.spec = {
        chart = "minecraft";
        version = "5.1.1";
        sourceRef = {
          kind = "HelmRepository";
          name = "itzg";
        };
      };
      values = {
        workloadAsStatefulSet = true;
        strategyType = "OnDelete";
        nodeSelector = {
          # "hcloud/node-group" = "gameserver-node";
          ops = "Djulia_";
          # "kubernetes.io/hostname" = "control-plane-2";
          "kubernetes.io/hostname" = "worker-1";
        };
        minecraftServer = {
          eula = "true";
          version = "26.1";
          type = "FABRIC";
          difficulty = "hard";
          viewDistance = 32;
          maxPlayers = 5;
          memory = "8096M";
          ops = "Djulia_";
          whitelist = ["Djulia_" "guitesnuit"] |> lib.concatStringsSep ",";
          modUrls = [
            "https://github.com/gnembon/fabric-carpet/releases/download/v26.1/fabric-carpet-26.1+v260402.jar"
            # "https://cdn.modrinth.com/data/P7dR8mSH/versions/G0yfY6x2/fabric-api-0.145.3%2B26.1.1.jar"
            # "https://cdn.modrinth.com/data/MBAkmtvl/versions/9GKnh8vV/balm-fabric-26.1-26.1.0.6.jar"
            # "https://cdn.modrinth.com/data/nPZr02ET/versions/lxYeKU5D/netherportalfix-fabric-26.1-26.1.0.1.jar"
            # "https://cdn.modrinth.com/data/XoHTb2Ap/versions/quBcj0Fx/calcmod-1.5.0%2Bfabric.26.1.jar"
            # "https://cdn.modrinth.com/data/TQTTVgYE/versions/6FpFtZPE/fabric-carpet-26.1-beta-1%2Bv251217.jar"
          ];
        };

        resources = {
          requests = {
            memory = "8096M";
            cpu = "2500m";
          };
          limits = {
            memory = "8096M";
            cpu = "5000m";
          };
        };

        rcon = {
          enabled = true;
          port = 25575;
          existingSecret = "rcon-credentials";
          secretKey = "password";
        };

        persistence.dataDir = {
          enabled = true;
          existingClaim = "minecraft";
        };
      };
    };

    # resources.gateways.minecraft.spec = {
    #   gatewayClassName = args.gatewayClassName;
    #   listeners = [
    #     {
    #       name = "http";
    #       protocol = "HTTP";
    #       port = 80;
    #       allowedRoutes.namespaces.from = "All";
    #     }
    #     {
    #       name = "https";
    #       protocol = "HTTPS";
    #       port = 443;
    #       allowedRoutes.namespaces.from = "All";
    #       tls = {
    #         mode = "Terminate";
    #         certificateRefs = [
    #           {
    #             kind = "Secret";
    #             name = args.tlsCertSecret;
    #           }
    #         ];
    #       };
    #     }
    #   ];
    # };

    resources.services.minecraft-nodeport.spec = {
      type = "NodePort";
      selector.app = "minecraft";
      ports = [
        {
          name = "minecraft";
          port = 25565;
          targetPort = 25565;
          protocol = "TCP";
          nodePort = 30565;
        }
      ];
    };
  };

  submodule = {
    name = "minecraft-server";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
