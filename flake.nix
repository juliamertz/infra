{
  inputs = {
    nixpkgs.follows = "srvos/nixpkgs";
    systems.url = "github:nix-systems/default";

    colmena.url = "github:zhaofengli/colmena";
    srvos.url = "github:nix-community/srvos";
    sops.url = "github:Mic92/sops-nix";

    dotfiles.url = "github:juliamertz/dotfiles";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    systems,
    colmena,
    rust-overlay,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;

    forAllSystems = fun:
      lib.genAttrs (import systems) (system:
        fun (nixpkgs.legacyPackages.${system}.extend rust-overlay.overlays.default));

    mkTarget = name: let
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
        imports = [./hive/gatekeeper.nix];
        deployment = mkTarget "gatekeeper";
      };

      main = {...}: {
        imports = [./hive/main.nix];
        deployment = mkTarget "main";
      };
    };

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        buildInputs = [];
        packages = with pkgs;
          [
            treefmt
            alejandra

            opentofu
            (writeShellScriptBin "colmena" ''
              ${lib.getExe colmena.packages.${system}.colmena} --experimental-flake-eval $@
            '')
          ]
          ++ (with pkgs.rust-bin.stable."1.86.0"; [
            rustfmt
            rust-analyzer
            (minimal.override {
              extensions = [
                "clippy"
                "rust-src"
              ];
            })
          ]);
      };
    });
  };
}
