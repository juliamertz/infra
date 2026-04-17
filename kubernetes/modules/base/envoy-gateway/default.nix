{
  config,
  kubenix,
  crds,
  lib,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
    crds
  ];

  options.submodule.args = with lib; {
    controllerReplicas = mkOption {
      type = types.int;
      default = 2;
    };

    configure = mkEnableOption ''
      Configure envoy by creating GatewayClass and EnvoyProxy resources
    '';

    envoy = {
      replicas = mkOption {
        type = types.int;
        default = 3;
      };

      pdbMinAvailable = mkOption {
        type = types.int;
        default = 2;
      };

      hpa = {
        maxReplicas = mkOption {
          type = types.int;
          default = 9;
        };

        targetCPU = mkOption {
          type = types.int;
          default = 60;
        };
      };
    };

    loadBalancer = {
      name = mkOption {
        type = types.str;
        default = "envoy-gateway-lb";
      };

      location = mkOption {
        type = types.str;
        default = "nbg1";
      };

      annotations = mkOption {
        type = types.attrsOf types.str;
        default = {};
      };
    };

    dragonfly.replicas = mkOption {
      type = types.int;
      default = 1;
    };
  };

  config.kubernetes = let
    args = config.submodule.args;
  in {
    namespace = "envoy-gateway-system";

    resources.namespaces.envoy-gateway-system = {};

    resources.helmRepositories.envoyproxy.spec = {
      type = "oci";
      url = "oci://docker.io/envoyproxy";
    };

    resources.helmReleases.gateway-helm.spec = {
      chart.spec = {
        chart = "gateway-helm";
        version = "1.7.2";
        sourceRef = {
          kind = "HelmRepository";
          name = "envoyproxy";
        };
      };
      values = {
        deployment.replicas = args.controllerReplicas;
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

    resources.gatewayclasses.envoy = lib.mkIf args.configure {
      spec = {
        controllerName = "gateway.envoyproxy.io/gatewayclass-controller";
        parametersRef = {
          group = "gateway.envoyproxy.io";
          kind = "EnvoyProxy";
          name = "hetzner-proxy-config";
          namespace = "envoy-gateway-system";
        };
      };
    };

    resources.envoyproxies.hetzner-proxy-config = lib.mkIf args.configure { spec = {
      provider = {
        type = "Kubernetes";
        kubernetes = {
          envoyService = {
            type = "LoadBalancer";
            annotations =
              {
                "load-balancer.hetzner.cloud/use-private-ip" = "true";
                "load-balancer.hetzner.cloud/location" = args.loadBalancer.location;
                "load-balancer.hetzner.cloud/algorithm-type" = "round_robin";
                "load-balancer.hetzner.cloud/name" = args.loadBalancer.name;
                "load-balancer.hetzner.cloud/uses-proxyprotocol" = "true";
              }
              // args.loadBalancer.annotations;
          };
          envoyPDB.minAvailable = args.envoy.pdbMinAvailable;
          envoyDeployment = {
            replicas = args.envoy.replicas;
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
            minReplicas = args.envoy.replicas;
            maxReplicas = args.envoy.hpa.maxReplicas;
            metrics = [
              {
                type = "Resource";
                resource = {
                  name = "cpu";
                  target = {
                    type = "Utilization";
                    averageUtilization = args.envoy.hpa.targetCPU;
                  };
                };
              }
            ];
          };
        };
      };
    }; };

    resources.dragonflies.envoy-ratelimit-db.spec = {
      image = "docker.dragonflydb.io/dragonflydb/dragonfly:v1.35.1";
      replicas = args.dragonfly.replicas;
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

  config.submodule = {
    name = "envoy-gateway";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
