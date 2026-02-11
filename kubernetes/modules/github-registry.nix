{
  kubenix,
  config,
  lib,
  ...
}: let
  cfg = config.kubernetes.githubRegistry;
in {
  imports = [
    kubenix.modules.submodule
    kubenix.modules.k8s
  ];

  options.kubernetes.githubRegistry = with lib; {
    dockerConfigJson = mkOption {
      description = "Value of the github registry secret, usually a GitHub PAT";
      type = types.str;
      default = "ref+sops://secrets/kubenix.yaml#github/registry/.dockerconfigjson";
    };
    namespaces = mkOption {
      description = "List of namespaces the secret should be created in";
      type = types.listOf types.str;
      default = [
        "cert-manager"
        "kube-system"
        "lightspeed-dhl-adapter"
        "valnetten"
        "vertrouwd-bouwen"
      ];
    };
  };

  config.kubernetes = {
    objects =
      map (namespace: {
        apiVersion = "v1";
        kind = "Secret";
        metadata = {
          name = "github-registry";
          inherit namespace;
        };
        type = "kubernetes.io/dockerconfigjson";
        stringData.".dockerconfigjson" = cfg.dockerConfigJson;
      })
      cfg.namespaces;
  };

  config.submodule = {
    name = "github-registry";
    passthru.kubernetes.objects = config.kubernetes.objects;
  };
}
