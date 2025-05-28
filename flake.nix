{
  inputs = {
    nixpkgs.follows = "srvos/nixpkgs";
    systems.url = "github:nix-systems/default";

    colmena.url = "github:zhaofengli/colmena";
    srvos.url = "github:nix-community/srvos";
    sops.url = "github:Mic92/sops-nix";

    dotfiles.url = "github:juliamertz/dotfiles";
  };

  outputs = {
    self,
    nixpkgs,
    systems,
    colmena,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;

    forAllSystems = fun:
      lib.genAttrs (import systems) (system:
        fun nixpkgs.legacyPackages.${system});

    mkTargetFromEnv = name: let
      targetEnv = key: builtins.getEnv "NIXOS_HOST_${lib.toUpper name}_${lib.toUpper key}";
    in {
      targetHost = targetEnv "ip";
      targetUser = targetEnv "ssh_user";
      targetPort = targetEnv "ssh_port" |> lib.strings.toIntBase10;
    };
  in {
    colmenaHive = colmena.lib.makeHive {
      meta = {
        nixpkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
          overlays = [];
        };
      };

      defaults = import ./hive/defaults.nix inputs;

      gatekeeper = {...}: {
        imports = [./hive/gatekeeper];
        deployment = mkTargetFromEnv "gatekeeper";
      };

      main = {...}: {
        imports = [./hive/main];
        deployment = mkTargetFromEnv "main";
      };
    };

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        buildInputs = [];
        packages = with pkgs; [
          treefmt
          alejandra

          (pkgs.stdenvNoCC.mkDerivation {
            inherit (pkgs.opentofu) meta pname version;
            src = pkgs.opentofu;
            nativeBuildInputs = [pkgs.makeWrapper];
            buildPhase = ''
              ln -sf $src/bin/tofu $out/bin/tofu-unwrapped
              makeWrapper $src/bin/tofu $out/bin/tofu \
                  --add-flags '-chdir="$TFDIR"'
            '';
          })

          (writeShellScriptBin "colmena" ''
            ${lib.getExe colmena.packages.${system}.colmena} --experimental-flake-eval $@
          '')
        ];
      };
    });
  };
}
