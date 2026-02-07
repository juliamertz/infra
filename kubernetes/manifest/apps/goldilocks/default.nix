{
  config,
  kubenix,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    ../../../type/fluxcd.nix
  ];

  config.kubernetes = {
    namespace = "goldilocks";

    resources.namespaces.goldilocks = {};

    resources.helmRepositories.fairwinds.spec = {
      url = "https://charts.fairwinds.com/stable";
    };

    resources.helmReleases.vpa.spec = {
      chart.spec = {
        chart = "vpa";
        version = "4.5.0";
        sourceRef = {
          kind = "HelmRepository";
          name = "fairwinds";
        };
      };
      install.crds = "CreateReplace";
      upgrade.crds = "CreateReplace";
      values = {
        recommender = {
          enabled = true;
          replicaCount = 1;
          resources = {
            requests = {
              cpu = "50m";
              memory = "128Mi";
            };
            limits = {
              cpu = "200m";
              memory = "512Mi";
            };
          };
          extraArgs = {
            storage = "checkpoint";
            checkpoints-gc-interval = "10m";
            pod-recommendation-min-cpu-millicores = 10;
            pod-recommendation-min-memory-mb = 10;
          };
        };
        updater.enabled = false;
        admissionController.enabled = false;
      };
    };

    resources.helmReleases.goldilocks.spec = {
      chart.spec = {
        chart = "goldilocks";
        version = "10.2.0";
        sourceRef = {
          kind = "HelmRepository";
          name = "fairwinds";
          namespace = "goldilocks";
        };
      };
      values = {
        dashboard = {
          replicaCount = 1;
          service.type = "ClusterIP";
        };
        vpa.enabled = false;
        controller = {
          flags.ignore-controller-kind = "Job,CronJob,Cluster,Prometheus";
          rbac.extraRules = [
            {
              apiGroups = ["postgresql.cnpg.io"];
              resources = ["clusters"];
              verbs = ["get" "list" "watch"];
            }
            {
              apiGroups = ["monitoring.coreos.com"];
              resources = ["prometheuses"];
              verbs = ["get" "list" "watch"];
            }
          ];
          resources = {
            requests = {
              cpu = "200m";
              memory = "128Mi";
            };
            limits = {
              cpu = "200m";
              memory = "128Mi";
            };
          };
        };
      };
    };
  };

  config.submodule = {
    name = "goldilocks";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
