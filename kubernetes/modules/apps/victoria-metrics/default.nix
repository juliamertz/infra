{
  config,
  kubenix,
  crds,
  util,
  lib,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = let
    vectorChart = {
      spec = {
        chart = "vector";
        version = "0.50.0";
        sourceRef = {
          kind = "HelmRepository";
          name = "vector";
        };
      };
    };
  in {
    namespace = "victoria-metrics";

    resources.namespaces.victoria-metrics.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
      "pod-security.kubernetes.io/audit" = "privileged";
      "pod-security.kubernetes.io/warn" = "privileged";
      "vector.dev/exclude" = "true";
    };

    resources.helmRepositories.victoria-metrics.spec = {
      url = "https://victoriametrics.github.io/helm-charts/";
    };
    resources.helmRepositories.vector.spec = {
      url = "https://helm.vector.dev";
    };

    resources.helmReleases.victoria-logs.spec = {
      chart.spec = {
        chart = "victoria-logs-single";
        version = "0.11.26";
        sourceRef = {
          kind = "HelmRepository";
          name = "victoria-metrics";
        };
      };
      values = {
        server = {
          fullnameOverride = "victoria-logs-server";
          retentionDiskSpaceUsage = "5GiB";
          persistentVolume = {
            size = "5Gi";
            storageClassName = "longhorn-local";
          };
        };
      };
    };

    resources.helmReleases.vector-aggregator.spec = {
      chart = vectorChart;
      values = {
        role = "Stateless-Aggregator";
        replicas = 3;
        customConfig = lib.importTOML ./aggregator.toml;
        resources = {
          requests = {
            memory = "64Mi";
            cpu = "50m";
          };
          limits = {
            memory = "128Mi";
            cpu = "100m";
          };
        };
      };
    };

    resources.helmReleases.vector-agent.spec = {
      chart = vectorChart;
      values = {
        role = "Agent";
        customConfig = lib.importTOML ./agent.toml;
        resources = {
          requests = {
            memory = "64Mi";
            cpu = "50m";
          };
          limits = {
            memory = "128Mi";
            cpu = "100m";
          };
        };
      };
    };
  };

  submodule = {
    name = "victoria-metrics";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
