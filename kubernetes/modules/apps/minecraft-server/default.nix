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
          "kubernetes.io/hostname" = "control-plane-2";
        };
        minecraftServer = {
          eula = "true";
          version = "26.1-pre-1";
          difficulty = "normal";
          whitelist = ["Djulia_" "guitesnuit"] |> lib.concatStringsSep ",";
          ops = "Djulia_";
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
