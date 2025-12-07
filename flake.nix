{
  inputs = {
    nixpkgs.follows = "srvos/nixpkgs";
    systems.url = "github:nix-systems/default";

    filter.url = "github:numtide/nix-filter";
    steiger.url = "github:brainhivenl/steiger";
    colmena.url = "github:zhaofengli/colmena";
    srvos.url = "github:nix-community/srvos";
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
    packages =
      forAllSystems (pkgs: {});

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

      # topdog = {...}: {
      #   imports = [./hive/topdog];
      #   deployment = mkTargetFromEnv "topdog";
      # };

      # cube = {...}: {
      #   imports = [./hive/cube];
      #   deployment = mkTargetFromEnv "cube";
      #   nixpkgs.system = "aarch64-linux";
      # };
    };

    devShells = forAllSystems (pkgs: let
      hcloud-upload-image = pkgs.callPackage ./pkgs/hcloud-upload-image.nix {};

      craneLib = mkCraneLib pkgs;
    in {
      default = craneLib.devShell {
        packages = with pkgs; [
          rust-analyzer
          jq
          yq
          treefmt
          alejandra
          packer
          hcloud
          talosctl
          colmena.packages.${system}.colmena
          steiger.packages.${system}.default
          nix-eval-jobs
          hcloud-upload-image
          awscli
          wget
          (pkgs.stdenvNoCC.mkDerivation {
            inherit (pkgs.opentofu) meta pname version;
            src = pkgs.opentofu;
            nativeBuildInputs = [pkgs.makeWrapper];
            buildPhase = ''
              makeWrapper $src/bin/tofu $out/bin/tofu \
                  --add-flags '-chdir="$TFDIR"'
              ln -sf $src/bin/tofu $out/bin/tofu-unwrapped
            '';
          })
        ];
      };
    });

    steigerImages = steiger.lib.eachCrossSystem (import systems) (localSystem: crossSystem: let
      pkgs = import nixpkgs {
        inherit overlays;
        system = localSystem;
      };
      pkgsCross = import nixpkgs {
        inherit overlays crossSystem localSystem;
      };

      craneLib = mkCraneLib pkgsCross;

      buildImage = package:
        pkgs.ociTools.buildImage {
          name = package.pname;
          tag = "latest";
          created = "now";

          copyToRoot = pkgsCross.buildEnv {
            name = "${package.pname}-sysroot";
            paths = [
              package
              pkgs.dockerTools.caCertificates
            ];
            pathsToLink = [
              "/bin"
              "/etc"
            ];
          };

          config.Cmd = ["/bin/${package.pname}"];
          compressor = "none";
        };

      controllers = pkgsCross.callPackage ./controllers/package.nix {
        inherit craneLib filter;
      };
    in {
      controllers = buildImage controllers;
    });
  };
}
