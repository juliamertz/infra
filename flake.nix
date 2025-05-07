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
    forAllSystems = fun:
      nixpkgs.lib.genAttrs (import systems) (system:
        fun nixpkgs.legacyPackages.${system});

    hiveArgs = {
      inherit inputs;
    };
  in {
    colmenaHive = colmena.lib.makeHive (import ./hive hiveArgs);

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        buildInputs = [];
        packages = with pkgs; [
          treefmt
          alejandra

          opentofu
          (writeShellScriptBin "colmena" ''
            ${lib.getExe colmena.packages.${system}.colmena} --experimental-flake-eval $@
          '')
        ];
      };
    });
  };
}
