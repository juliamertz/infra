{
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
        # nodeSelector = {
        #   "hcloud/node-group" = "gameserver-node";
        # };
        minecraftServer = {
          eula = "true";
          version = "1.21.1";
          difficulty = "normal";
          # whitelist = ["Djulia_" "guitesnuit"];
          # ops = ["Djulia_"];
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
