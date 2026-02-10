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
    ./database.nix
    ./release.nix
    ./route.nix
  ];

  kubernetes = {
    namespace = "authelia";

    resources.namespaces.authelia = {};

    resources.referenceGrants.allow-securitypolicy-from-tailscale-agent.spec = {
      from = [
        {
          group = "gateway.envoyproxy.io";
          kind = "SecurityPolicy";
          namespace = "tailscale-agent";
        }
        {
          group = "gateway.envoyproxy.io";
          kind = "SecurityPolicy";
          namespace = "monitoring";
        }
        {
          group = "gateway.envoyproxy.io";
          kind = "SecurityPolicy";
          namespace = "merlijn-portfolio";
        }
        {
          group = "gateway.envoyproxy.io";
          kind = "SecurityPolicy";
          namespace = "miniflux";
        }
      ];
      to = [
        {
          group = "";
          kind = "Service";
          name = "authelia";
        }
      ];
    };
  };

  submodule = {
    name = "authelia";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
