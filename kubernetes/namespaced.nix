{
  config,
  kubenix,
  lib,
  name,
  # This is a shorthand for config.submodule.args and contains
  # final values of the args options.
  args,
  ...
}: {
  imports = with kubenix.modules; [
    submodule
    k8s
  ];

  options.submodule.args = {
    kubernetes = lib.mkOption {
      description = "Kubernetes config to be applied to a specific namespace.";
      type = lib.types.attrs;
      default = {};
    };
  };

  config = {
    submodule = {
      name = "namespaced";

      passthru.kubernetes.objects = config.kubernetes.objects;
    };

    kubernetes = lib.mkMerge [
      # {namespace = name;}
      # # Create namespace object
      # {resources.namespaces.${name} = {};}

      args.kubernetes
    ];
  };
}

