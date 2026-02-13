{
  pkgs,
  packages,
}: let
  helmRepos =
    packages.manifest.passthru.module.config.kubernetes.generated.items
    |> builtins.filter (i: i.kind == "HelmRepository")
    |> map (i: {
      name = i.metadata.name;
      url = i.spec.url;
      isOci = (i.spec.type or null) == "oci";
    });

  mkMatchString = name: "chart\\s*=\\s*\"(?<depName>[^\"]+)\";\\s*version\\s*=\\s*\"(?<currentValue>[^\"]+)\";\\s*sourceRef\\s*=\\s*\\{[^}]*name\\s*=\\s*\"${name}\"";

  mkManager = repo:
    if repo.isOci
    then {
      customType = "regex";
      managerFilePatterns = ["/^.*\\.nix$/"];
      matchStrings = [(mkMatchString repo.name)];
      datasourceTemplate = "docker";
      packageNameTemplate = "${builtins.replaceStrings ["oci://"] [""] repo.url}/{{depName}}";
    }
    else {
      customType = "regex";
      managerFilePatterns = ["/^.*\\.nix$/"];
      matchStrings = [(mkMatchString repo.name)];
      datasourceTemplate = "helm";
      registryUrlTemplate = repo.url;
    };
in
  {
    "$schema" = "https://docs.renovatebot.com/renovate-schema.json";
    extends = [
      "config:recommended"
    ];
    kubernetes = {
      managerFilePatterns = [
        "/(^|/)kustomization\\.ya?ml$/"
      ];
      pinDigests = true;
    };
    flux = {
      managerFilePatterns = [
        "/k8s/.+\\.yaml$/"
      ];
    };
    customManagers = map mkManager helmRepos;
  }
  |> builtins.toJSON
  |> (text: pkgs.writeText "renovate" text)
