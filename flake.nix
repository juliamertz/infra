{
  inputs = {
    nixpkgs.follows = "srvos/nixpkgs";
    systems.url = "github:nix-systems/default";

    colmena.url = "github:zhaofengli/colmena";
    srvos.url = "github:nix-community/srvos";
    sops.url = "github:Mic92/sops-nix";
    lightspeed-dhl-adapter.url = "github:juliamertz/lightspeed-dhl-adapter";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    # nix-minecraft.url = "github:nathanregner/nix-minecraft/4c27ffe58bc42627f86bbc19779024db1a49a7f3";

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
    overlays = [inputs.nix-minecraft.overlay];
    forAllSystems = fun:
      lib.genAttrs (import systems) (system:
        fun (import nixpkgs {
          inherit system;
          inherit overlays;
        }));

    mkTargetFromEnv = name: let
      targetEnv = key: builtins.getEnv "NIXOS_HOST_${lib.toUpper name}_${lib.toUpper key}";
    in {
      targetHost = targetEnv "ip";
      targetUser = targetEnv "ssh_user";
      targetPort = targetEnv "ssh_port" |> lib.strings.toIntBase10;
    };
  in {
    packages = forAllSystems (pkgs:  {
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

      gatekeeper = {...}: {
        imports = [./hive/gatekeeper];
        deployment = mkTargetFromEnv "gatekeeper";
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

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        buildInputs = [];
        packages = with pkgs; [
          treefmt
          alejandra

          colmena.packages.${system}.colmena
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
  };
}
