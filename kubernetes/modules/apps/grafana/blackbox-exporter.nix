{
  kubernetes = {
    resources.helmReleases.blackbox-exporter.spec = {
      interval = "5m";
      chart.spec = {
        chart = "prometheus-blackbox-exporter";
        version = "11.8.0";
        sourceRef = {
          kind = "HelmRepository";
          name = "prometheus-community";
        };
        interval = "1m";
      };
      values = {
        fullnameOverride = "blackbox-exporter";
        resources = {
          requests = {
            cpu = "10m";
            memory = "48Mi";
          };
          limits = {
            cpu = "50m";
            memory = "128Mi";
          };
        };
        releaseLabel = true;
        serviceMonitor.enabled = true;
        replicas = 2;
        podDisruptionBudget.maxUnavailable = 1;
        config.modules.http_2xx = {
          prober = "http";
          timeout = "5s";
          http = {
            valid_http_versions = ["HTTP/1.1" "HTTP/2.0"];
            follow_redirects = true;
            preferred_ip_protocol = "ip4";
          };
        };
      };
    };
  };
}
