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
    namespace = "valheim";

    resources.namespaces.valheim = {};

    resources.persistentVolumeClaims.valheim-world.spec = {
      storageClassName = "hcloud-volumes";
      accessModes = ["ReadWriteOnce"];
      resources.requests.storage = "10Gi";
    };

    resources.persistentVolumeClaims.valheim-data.spec = {
      storageClassName = "hcloud-volumes";
      accessModes = ["ReadWriteOnce"];
      resources.requests.storage = "1Gi";
    };

    resources.statefulSets.valheim-server = {
      metadata.labels.app = "valheim-server";
      spec = {
        replicas = 1;
        selector.matchLabels.app = "valheim-server";
        template = {
          metadata = {
            labels = {
              app = "valheim-server";
              "dns.juliamertz.dev/hostdns" = "true";
            };
            annotations = {
              "dns.juliamertz.dev/hostname" = "valheim.juliamertz.nl";
              "dns.juliamertz.dev/delete-after" = "24h";
              "dns.juliamertz.dev/ttl" = "60";
            };
          };
          spec = {
            terminationGracePeriodSeconds = 120;
            shareProcessNamespace = true;
            hostNetwork = true;
            containers = [
              {
                name = "valheim";
                image = "mbround18/valheim:3.5.0";
                imagePullPolicy = "IfNotPresent";
                env = [
                  {
                    name = "NAME";
                    value = "Julia's server";
                  }
                  {
                    name = "WORLD";
                    value = "Julia's realm";
                  }
                  {
                    name = "TYPE";
                    value = "BepInEx";
                  }
                  {
                    name = "MODS";
                    value = "ValheimModding-Jotunn-*\nJereKuusela-Server_devcommands-1.101.0\nComfyMods-TorchesAndResin-1.8.0";
                  }
                  {
                    name = "MODIFIERS";
                    value = "resources=more,raids=muchless";
                  }
                  {
                    name = "PORT";
                    value = "2456";
                  }
                  {
                    name = "HTTP_PORT";
                    value = "9000";
                  }
                  {
                    name = "TZ";
                    value = "Europe/Amsterdam";
                  }
                  {
                    name = "PUBLIC";
                    value = "1";
                  }
                  {
                    name = "UPDATE_ON_STARTUP";
                    value = "0";
                  }
                  {
                    name = "PASSWORD";
                    valueFrom.secretKeyRef = {
                      name = "valheim-auth";
                      key = "password";
                      optional = false;
                    };
                  }
                ];
                ports = [
                  {
                    containerPort = 2456;
                    name = "gameport";
                  }
                  {
                    containerPort = 2457;
                    name = "queryport";
                  }
                  {
                    containerPort = 9000;
                    name = "metrics";
                  }
                ];
                volumeMounts = [
                  {
                    name = "gamefiles";
                    mountPath = "/home/steam/.config/unity3d/IronGate/Valheim";
                  }
                  {
                    name = "serverfiles";
                    mountPath = "/home/steam/valheim";
                  }
                ];
                resources = {
                  requests = {
                    cpu = "500m";
                    memory = "2Gi";
                  };
                  limits = {
                    cpu = "1500m";
                    memory = "4Gi";
                  };
                };
              }
              {
                name = "debugger";
                image = "alpine:latest";
                imagePullPolicy = "IfNotPresent";
                args = ["sh" "-c" "trap 'exit 0' TERM; sleep infinity & wait"];
                volumeMounts = [
                  {
                    name = "gamefiles";
                    mountPath = "/gamefiles";
                  }
                  {
                    name = "serverfiles";
                    mountPath = "/serverfiles";
                  }
                ];
              }
            ];
            volumes = [
              {
                name = "gamefiles";
                persistentVolumeClaim.claimName = "valheim-world";
              }
              {
                name = "serverfiles";
                persistentVolumeClaim.claimName = "valheim-data";
              }
            ];
          };
        };
      };
    };

    resources.podMonitors.valheim-monitor = {
      metadata.labels.release = "kube-prometheus-stack";
      spec = {
        podMetricsEndpoints = [
          {port = "metrics";}
        ];
        selector.matchLabels.app = "valheim-server";
      };
    };

    resources.cronJobs.valheim-backup.spec = {
      schedule = "0 2 * * *";
      concurrencyPolicy = "Forbid";
      successfulJobsHistoryLimit = 3;
      failedJobsHistoryLimit = 3;
      jobTemplate.spec = {
        backoffLimit = 2;
        template.spec = {
          restartPolicy = "OnFailure";
          serviceAccountName = "backup-sa";
          containers = [
            {
              name = "backup";
              image = "nixery.dev/shell/kubectl/awscli";
              env = [
                {
                  name = "POD_NAME";
                  value = "valheim-server-0";
                }
                {
                  name = "CONTAINER_NAME";
                  value = "valheim";
                }
                {
                  name = "NAMESPACE";
                  value = "valheim";
                }
                {
                  name = "SOURCE_PATH";
                  value = "/home/steam/.config/unity3d/IronGate/Valheim/worlds_local";
                }
                {
                  name = "S3_BUCKET";
                  value = "valheim-backups";
                }
                {
                  name = "BACKUP_PREFIX";
                  value = "backups/valheim";
                }
                {
                  name = "S3_ENDPOINT";
                  value = "http://garage.garage:3900";
                }
                {
                  name = "AWS_ACCESS_KEY_ID";
                  valueFrom.secretKeyRef = {
                    name = "s3-credentials";
                    key = "access-key-id";
                  };
                }
                {
                  name = "AWS_SECRET_ACCESS_KEY";
                  valueFrom.secretKeyRef = {
                    name = "s3-credentials";
                    key = "secret-access-key";
                  };
                }
              ];
              command = [
                "/bin/sh"
                "-c"
                ''
                  set -e

                  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
                  echo "Starting backup at $TIMESTAMP"

                  mkdir -p /world

                  kubectl cp -c valheim $POD_NAME:"$SOURCE_PATH/Julia's.db" /world/world.db

                  if [ ! -s /world/world.db ]; then
                    echo "ERROR: world.db is missing or empty"
                    exit 1
                  fi

                  kubectl cp -c valheim $POD_NAME:"$SOURCE_PATH/Julia's.fwl" /world/world.fwl

                  if [ ! -s /world/world.fwl ]; then
                    echo "ERROR: world.fwl is missing or empty"
                    exit 1
                  fi

                  aws --endpoint-url $S3_ENDPOINT s3 sync /world s3://$S3_BUCKET/$BACKUP_PREFIX/$TIMESTAMP/

                  echo "Backup completed"
                ''
              ];
            }
          ];
        };
      };
    };

    resources.serviceAccounts.backup-sa = {};

    resources.roles.backup-role.rules = [
      {
        apiGroups = [""];
        resources = ["pods/exec"];
        verbs = ["create"];
      }
      {
        apiGroups = [""];
        resources = ["pods"];
        verbs = ["get"];
      }
    ];

    resources.roleBindings.backup-rolebinding = {
      subjects = [
        {
          kind = "ServiceAccount";
          name = "backup-sa";
          namespace = "valheim";
        }
      ];
      roleRef = {
        kind = "Role";
        name = "backup-role";
        apiGroup = "rbac.authorization.k8s.io";
      };
    };
  };

  submodule = {
    name = "valheim-server";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
