{
  config,
  lib,
  pkgs,
  kubenix,
  ...
}: {
  imports = with kubenix.modules; [submodules k8s];

  kubernetes = {
    namespace = "envoy-gateway-system";

    resources.namespaces.envoy-gateway-system = {};

    resources.helmrepositories.envoyproxy.spec = {
      type = "oci";
      url = "oci://docker.io/envoyproxy";
    };

    resources.helmreleases.gateway-helm.spec = {
      interval = "5m";
      chart.spec = {
        chart = "gateway-helm";
        version = "1.7.0";
        sourceRef = {
          kind = "HelmRepository";
          name = "envoyproxy";
        };
      };
      values = {
        deployment.replicas = 2;
        config.envoyGateway = {
          gateway.controllerName = "gateway.envoyproxy.io/gatewayclass-controller";
          provider = {
            type = "Kubernetes";
            kubernetes.deploy.type = "GatewayNamespace";
          };
          extensionApis = {
            enableEnvoyPatchPolicy = true;
            enableBackend = true;
          };
          rateLimit.backend = {
            type = "Redis";
            redis.url = "envoy-ratelimit-db.envoy-gateway-system.svc.cluster.local:6379";
          };
        };
      };
    };

    resources.gatewayclasses.envoy.spec = {
      controllerName = "gateway.envoyproxy.io/gatewayclass-controller";
      parametersRef = {
        group = "gateway.envoyproxy.io";
        kind = "EnvoyProxy";
        name = "hetzner-proxy-config";
        namespace = "envoy-gateway-system";
      };
    };

    resources.envoyproxies.hetzner-proxy-config.spec = {
      provider = {
        type = "Kubernetes";
        kubernetes = {
          envoyService = {
            type = "LoadBalancer";
            annotations = {
              "load-balancer.hetzner.cloud/use-private-ip" = "true";
              "load-balancer.hetzner.cloud/location" = "nbg1";
              "load-balancer.hetzner.cloud/algorithm-type" = "round_robin";
              "load-balancer.hetzner.cloud/name" = "envoy-gateway-shared-lb";
              "load-balancer.hetzner.cloud/uses-proxyprotocol" = "true";
            };
          };
          envoyPDB.minAvailable = 2;
          envoyDeployment = {
            replicas = 3;
            strategy.rollingUpdate = {
              maxSurge = 1;
              maxUnavailable = 0;
            };
            pod.topologySpreadConstraints = [
              {
                maxSkew = 1;
                topologyKey = "kubernetes.io/hostname";
                whenUnsatisfiable = "DoNotSchedule";
                labelSelector.matchLabels = {
                  "app.kubernetes.io/name" = "envoy";
                };
                matchLabelKeys = [
                  "pod-template-hash"
                  "gateway.envoyproxy.io/owning-gateway-name"
                  "gateway.envoyproxy.io/owning-gateway-namespace"
                ];
              }
            ];
          };
          envoyHpa = {
            minReplicas = 3;
            maxReplicas = 9;
            metrics = [
              {
                type = "Resource";
                resource = {
                  name = "cpu";
                  target = {
                    type = "Utilization";
                    averageUtilization = 60;
                  };
                };
              }
            ];
          };
        };
      };
    };

    resources.dragonflies.envoy-ratelimit-db.spec = {
      image = "docker.dragonflydb.io/dragonflydb/dragonfly:v1.35.1";
      replicas = 1;
      resources = {
        requests = {
          memory = "512Mi";
          cpu = "100m";
        };
        limits = {
          memory = "512Mi";
          cpu = "100m";
        };
      };
    };
  };
}
