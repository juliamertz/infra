{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-cross.url = "github:nixos/nixpkgs/90ade7da38aa49c2e2693a04a44662a0e61530e9";
    systems.url = "github:nix-systems/default";
    filter.url = "github:numtide/nix-filter";
    steiger.url = "github:brainhivenl/steiger";
    colmena.url = "github:zhaofengli/colmena";
    kubenix.url = "github:hall/kubenix";
    sops.url = "github:Mic92/sops-nix";
    lightspeed-dhl-adapter.url = "github:juliamertz/lightspeed-dhl-adapter";
    nix-minecraft.url = "github:juliamertz/nix-minecraft";
    dotfiles.url = "github:juliamertz/dotfiles";
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    steiger,
    nixpkgs,
    nixpkgs-cross,
    kubenix,
    systems,
    colmena,
    crane,
    filter,
    rust-overlay,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;
    overlays = [
      (import rust-overlay)
      inputs.nix-minecraft.overlay
      steiger.overlays.ociTools
    ];
    mkCraneLib = pkgs': (crane.mkLib pkgs').overrideToolchain (p: p.rust-bin.stable."1.90.0".default);

    forAllSystems = fun:
      lib.genAttrs (import systems) (system:
        fun (import nixpkgs {
          inherit system;
          inherit overlays;
          config.allowUnfree = true;
        }));

    mkTargetFromEnv = name: let
      targetEnv = key: builtins.getEnv "NIXOS_HOST_${lib.toUpper name}_${lib.toUpper key}";
    in {
      targetHost = targetEnv "ip";
      targetUser = targetEnv "ssh_user";
      targetPort = targetEnv "ssh_port" |> lib.strings.toIntBase10;
    };
  in {
    packages = forAllSystems (pkgs: rec {
      k8s = import ./kubernetes {inherit pkgs kubenix;};
      manifest = k8s.config.kubernetes.result;

      renovateConfig = let
        helmRepos =
          k8s.config.kubernetes.generated.items
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
        |> (text: pkgs.writeText "renovate" text);
    });

    colmenaHive = colmena.lib.makeHive {
      meta = {
        nixpkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
          overlays = [];
        };
        specialArgs = {
          inherit inputs;
        };
      };

      defaults = import ./hive/defaults.nix inputs;

      bastion = {...}: {
        imports = [./hive/bastion];
        deployment = mkTargetFromEnv "bastion";
      };

      topdog = {...}: {
        imports = [./hive/topdog];
        deployment = mkTargetFromEnv "topdog";
      };

      cube = {...}: {
        imports = [./hive/cube];
        deployment = mkTargetFromEnv "cube";
        nixpkgs.system = "aarch64-linux";
      };
    };

    devShells = forAllSystems (pkgs: let
      inherit (pkgs.stdenv.hostPlatform) system;

      hcloud-upload-image = pkgs.callPackage ./pkgs/hcloud-upload-image.nix {};

      tofu = pkgs.stdenvNoCC.mkDerivation {
        inherit (pkgs.opentofu) meta pname version;
        src = pkgs.opentofu;
        nativeBuildInputs = [pkgs.makeWrapper];
        buildPhase = ''
          makeWrapper $src/bin/tofu $out/bin/tofu \
              --add-flags '-chdir="$TFDIR"'
          ln -sf $src/bin/tofu $out/bin/tofu-unwrapped
        '';
      };

      craneLib = mkCraneLib pkgs;

      k8s-diff = pkgs.writeShellScript "k8s-diff" ''
        ${lib.getExe pkgs.colordiff} --nobanner -N -u -I ' kubenix/' -I ' generation: ' "$@"
      '';
      k8s-build = pkgs.writeShellScriptBin "k8s-build" ''
        nix build .#manifest
      '';
      k8s-apply = pkgs.writeShellScriptBin "k8s-apply" ''
        k8s-build && ${lib.getExe pkgs.kubectl} apply --server-side --force-conflicts -f result
      '';
      k8s-diffcmd = pkgs.writeShellScriptBin "k8s-diff" ''
        k8s-build && KUBECTL_EXTERNAL_DIFF='${k8s-diff}' ${lib.getExe pkgs.kubectl} diff --server-side --force-conflicts -f result
      '';
    in {
      default = craneLib.devShell {
        packages = [
          pkgs.rust-analyzer
          pkgs.jq
          pkgs.yq
          pkgs.treefmt
          pkgs.alejandra
          pkgs.packer
          pkgs.hcloud
          pkgs.talosctl
          pkgs.nix-eval-jobs
          pkgs.awscli
          pkgs.wget
          k8s-build
          k8s-apply
          k8s-diffcmd
          colmena.packages.${system}.colmena
          steiger.packages.${system}.default
          hcloud-upload-image
          tofu
        ];
      };
    });

    steigerImages = steiger.lib.eachCrossSystem (import systems) (localSystem: crossSystem: let
      pkgs = import nixpkgs {
        inherit overlays;
        system = localSystem;
      };
      pkgsTarget = import nixpkgs-cross {
        inherit overlays;
        system = crossSystem;
      };
      pkgsCross = import nixpkgs-cross {
        inherit overlays crossSystem localSystem;
      };

      craneLib = mkCraneLib pkgsCross;

      controllers = pkgsCross.callPackage ./controllers/package.nix {
        inherit craneLib filter;
      };

      sysroot = pkgsCross.buildEnv {
        name = "${controllers.pname}-sysroot";
        paths = [
          controllers
          pkgsTarget.nix
          pkgs.dockerTools.caCertificates
        ];
        pathsToLink = [
          "/bin"
          "/etc"
        ];
      };
    in {
      controllers = pkgs.ociTools.buildImage {
        name = controllers.pname;
        tag = "latest";
        created = "now";

        copyToRoot = sysroot;

        config.Cmd = ["/bin/${controllers.pname}"];
      };
    });
  };
}
