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
    namespace = "headscale";

    resources.namespaces.headscale = {};

    resources.certificates.headscale-tls.spec = {
      secretName = "headscale-tls";
      issuerRef = {
        name = "letsencrypt-prod";
        kind = "ClusterIssuer";
      };
      dnsNames = ["headscale.juliamertz.nl"];
    };

    resources.cnpgClusters.headscale-db.spec = {
      instances = 2;
      primaryUpdateStrategy = "unsupervised";
      primaryUpdateMethod = "switchover";
      enableSuperuserAccess = false;
      storage = {
        size = "2Gi";
        storageClass = "longhorn-local";
        resizeInUseVolumes = true;
      };
    };

    resources.services.headscale.spec = {
      type = "NodePort";
      selector."app.kubernetes.io/name" = "headscale-central";
      ports = [
        {
          name = "https";
          port = 443;
          targetPort = 8080;
          protocol = "TCP";
          nodePort = 30443;
        }
        {
          name = "derp";
          port = 3478;
          targetPort = 3478;
          protocol = "UDP";
          nodePort = 30478;
        }
      ];
    };

    resources.services.headscale-metrics.spec = {
      type = "ClusterIP";
      selector."app.kubernetes.io/name" = "headscale-central";
      ports = [
        {
          name = "metrics";
          port = 9090;
          targetPort = 9090;
          protocol = "TCP";
        }
      ];
    };

    resources.services.headscale-metrics.metadata.labels = {
      "app.kubernetes.io/name" = "headscale";
      "app.kubernetes.io/part-of" = "headscale";
      "app.kubernetes.io/component" = "metrics";
    };

    resources.headscalePolicies.central.spec = {
      headscaleRef.name = "central";
      acls = [
        {
          action = "accept";
          src = ["autogroup:member"];
          dst = ["autogroup:self:*"];
        }
        {
          action = "accept";
          src = ["julia@"];
          dst = ["*:*"];
        }
        {
          action = "accept";
          src = ["kubernetes@"];
          dst = ["homelab@:8123,8096"];
        }
      ];
    };

    resources.headscales.central.spec = {
      tls.existingSecret = "headscale-tls";
      config = {
        server_url = "https://headscale.juliamertz.nl:30443";
        tls_cert_path = "/etc/headscale/tls/tls.crt";
        tls_key_path = "/etc/headscale/tls/tls.key";
        listen_addr = "0.0.0.0:8080";
        metrics_listen_addr = "0.0.0.0:9090";
        grpc_listen_addr = "0.0.0.0:50443";
        grpc_allow_insecure = false;
        private_key_path = "/var/lib/headscale/private.key";
        noise.private_key_path = "/var/lib/headscale/noise_private.key";
        prefixes = {
          v4 = "100.64.0.0/10";
          v6 = "fd7a:115c:a1e0::/48";
        };
        derp = {
          server = {
            enabled = true;
            region_id = 999;
            region_code = "hetzner";
            region_name = "Hetzner";
            stun_listen_addr = "0.0.0.0:3478";
            private_key_path = "/var/lib/headscale/derp_server_private.key";
          };
          urls = [];
          auto_update_enabled = false;
        };
        dns = {
          override_local_dns = true;
          base_domain = "headscale.local";
          magic_dns = true;
          nameservers.global = [
            "1.1.1.1"
            "8.8.8.8"
          ];
        };
      };
      deployment = {
        image = "headscale/headscale:v0.28.0";
        env = [
          {
            name = "HEADSCALE_DATABASE_TYPE";
            value = "postgres";
          }
          {
            name = "HEADSCALE_DATABASE_POSTGRES_HOST";
            valueFrom.secretKeyRef = {
              name = "headscale-db-app";
              key = "host";
            };
          }
          {
            name = "HEADSCALE_DATABASE_POSTGRES_NAME";
            valueFrom.secretKeyRef = {
              name = "headscale-db-app";
              key = "dbname";
            };
          }
          {
            name = "HEADSCALE_DATABASE_POSTGRES_USER";
            valueFrom.secretKeyRef = {
              name = "headscale-db-app";
              key = "username";
            };
          }
          {
            name = "HEADSCALE_DATABASE_POSTGRES_PASS";
            valueFrom.secretKeyRef = {
              name = "headscale-db-app";
              key = "password";
            };
          }
        ];
      };
    };

    resources.serviceMonitors.headscale = {
      metadata.labels.release = "kube-prometheus-stack";
      spec = {
        endpoints = [
          {
            interval = "30s";
            path = "/metrics";
            port = "metrics";
          }
        ];
        namespaceSelector.matchNames = ["headscale"];
        selector.matchLabels = {
          "app.kubernetes.io/part-of" = "headscale";
          "app.kubernetes.io/component" = "metrics";
        };
      };
    };

    resources.podMonitors.headscale-db = {
      metadata.labels.release = "kube-prometheus-stack";
      spec = {
        selector.matchLabels = {
          "cnpg.io/cluster" = "headscale-db";
          "cnpg.io/instanceRole" = "replica";
        };
        podMetricsEndpoints = [
          {port = "metrics";}
        ];
      };
    };

    resources.probes.headscale-probe = {
      metadata.labels.release = "kube-prometheus-stack";
      spec = {
        interval = "30s";
        module = "http_2xx";
        prober.url = "blackbox-exporter.monitoring:9115";
        targets.staticConfig.static = [
          "https://headscale.juliamertz.nl:30443/health"
        ];
      };
    };
  };

  submodule = {
    name = "headscale";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
