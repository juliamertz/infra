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
    namespace = "longhorn-system";

    resources.namespaces.longhorn-system.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
      "pod-security.kubernetes.io/audit" = "privileged";
      "pod-security.kubernetes.io/warn" = "privileged";
      "pod-security.kubernetes.io/enforce-version" = "latest";
      "pod-security.kubernetes.io/audit-version" = "latest";
      "pod-security.kubernetes.io/warn-version" = "latest";
    };

    resources.helmRepositories.longhorn.spec = {
      url = "https://charts.longhorn.io";
    };

    resources.helmReleases.longhorn.spec = {
      chart.spec = {
        chart = "longhorn";
        version = "1.11.0";
        sourceRef = {
          kind = "HelmRepository";
          name = "longhorn";
        };
      };
      values = {
        global.tolerations = [
          {
            key = "node-role.kubernetes.io/control-plane";
            operator = "Exists";
            effect = "NoSchedule";
          }
        ];
        image.longhorn.instanceManager.tag = "v1.11.0-hotfix-1";
        longhornManager.resources = {
          requests = {
            cpu = "50m";
            memory = "256Mi";
          };
          limits = {
            cpu = "200m";
            memory = "768Mi";
          };
        };
        defaultSettings.systemManagedCSIComponentsResourceLimits = builtins.toJSON {
          csi-attacher = {
            requests = {
              cpu = "10m";
              memory = "32Mi";
            };
            limits = {
              cpu = "50m";
              memory = "128Mi";
            };
          };
          csi-provisioner = {
            requests = {
              cpu = "10m";
              memory = "32Mi";
            };
            limits = {
              cpu = "50m";
              memory = "128Mi";
            };
          };
          csi-resizer = {
            requests = {
              cpu = "10m";
              memory = "32Mi";
            };
            limits = {
              cpu = "50m";
              memory = "96Mi";
            };
          };
          csi-snapshotter = {
            requests = {
              cpu = "10m";
              memory = "32Mi";
            };
            limits = {
              cpu = "50m";
              memory = "96Mi";
            };
          };
          longhorn-csi-plugin = {
            requests = {
              cpu = "15m";
              memory = "48Mi";
            };
            limits = {
              cpu = "50m";
              memory = "128Mi";
            };
          };
          node-driver-registrar = {
            requests = {
              cpu = "10m";
              memory = "16Mi";
            };
            limits = {
              cpu = "50m";
              memory = "64Mi";
            };
          };
          longhorn-liveness-probe = {
            requests = {
              cpu = "10m";
              memory = "32Mi";
            };
            limits = {
              cpu = "50m";
              memory = "64Mi";
            };
          };
        };
      };
    };

    resources.storageClasses.longhorn-local = {
      provisioner = "driver.longhorn.io";
      allowVolumeExpansion = true;
      parameters = {
        numberOfReplicas = "1";
        dataLocality = "strict-local";
      };
    };
  };

  submodule = {
    name = "longhorn";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
