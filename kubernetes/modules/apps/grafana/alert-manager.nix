{
  kubernetes = {
    resources.deployments.alertmanager-discord = {
      metadata.labels.app = "alertmanager-discord";
      spec = {
        replicas = 2;
        selector.matchLabels.app = "alertmanager-discord";
        template = {
          metadata.labels.app = "alertmanager-discord";
          spec.containers = [
            {
              name = "alertmanager-discord";
              image = "ghcr.io/rogerrum/alertmanager-discord:1.0.7";
              env = [
                {
                  name = "DISCORD_USERNAME";
                  value = "alertmanager";
                }
                {
                  name = "DISCORD_AVATAR_URL";
                  value = "";
                }
                {
                  name = "DISCORD_WEBHOOK";
                  valueFrom.secretKeyRef = {
                    key = "webhookUrl";
                    name = "alertmanager-discord-secret";
                  };
                }
                {
                  name = "LISTEN_ADDRESS";
                  value = "0.0.0.0:9094";
                }
                {
                  name = "VERBOSE";
                  value = "ON";
                }
              ];
              ports = [
                {
                  name = "http";
                  containerPort = 9094;
                }
              ];
              resources = {
                requests = {
                  cpu = "20m";
                  memory = "40Mi";
                };
                limits = {
                  cpu = "20m";
                  memory = "40Mi";
                };
              };
            }
          ];
        };
      };
    };

    resources.services.alertmanager-discord = {
      metadata.labels.app = "alertmanager-discord";
      spec = {
        type = "ClusterIP";
        ports = [
          {
            name = "http";
            port = 9094;
            protocol = "TCP";
            targetPort = 9094;
          }
        ];
        selector.app = "alertmanager-discord";
      };
    };
  };
}
