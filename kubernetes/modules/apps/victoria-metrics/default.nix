{
  config,
  kubenix,
  crds,
  ...
}: let
  sourceRef = {
    kind = "HelmRepository";
    name = "victoria-metrics";
  };
in {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  kubernetes = {
    namespace = "victoria-metrics";

    resources.namespaces.victoria-metrics.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
      "pod-security.kubernetes.io/audit" = "privileged";
      "pod-security.kubernetes.io/warn" = "privileged";
    };

    resources.helmRepositories.${sourceRef.name}.spec = {
      url = "https://victoriametrics.github.io/helm-charts/";
    };

    resources.helmReleases.victoria-logs.spec = {
      chart.spec = {
        chart = "victoria-logs-single";
        version = "0.11.26";
        inherit sourceRef;
      };
      values = {
        server = {
          fullnameOverride = "victoria-logs-server";
          # retentionPeriod = "14d";
          retentionDiskSpaceUsage = "5GiB";
          persistentVolume = {
            size = "5Gi";
            storageClassName = "longhorn-local";
          };
        };
      };
    };

    resources.helmReleases.victoria-logs-collector.spec = {
      chart.spec = {
        chart = "victoria-logs-collector";
        version = "0.2.9";
        inherit sourceRef;
      };
      values = {
        remoteWrite = [{url = "http://victoria-logs-server:9428";}];
        collector = {
          # fullnameOverride = "victoria-logs-collector";
        };
      };
    };
  };

  submodule = {
    name = "victoria-metrics";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
