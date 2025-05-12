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
    forAllSystems = fun:
      nixpkgs.lib.genAttrs (import systems) (system:
        fun (nixpkgs.legacyPackages.${system}.extend rust-overlay.overlays.default));

    hiveArgs = {
      inherit inputs;
    };
  in {
    colmenaHive = colmena.lib.makeHive (import ./hive hiveArgs);

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
