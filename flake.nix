{
  inputs = {
    nixpkgs.follows = "srvos/nixpkgs";
    srvos.url = "github:nix-community/srvos";
    systems.url = "github:nix-systems/default";
    dotfiles.url = "github:juliamertz/dotfiles";
    sops.url = "github:Mic92/sops-nix";
  };

  outputs = {
    nixpkgs,
    systems,
    ...
  } @ inputs: let
    forAllSystems = fun:
      nixpkgs.lib.genAttrs (import systems) (system:
        fun nixpkgs.legacyPackages.${system});
  in {
    nixosConfigurations = import ./nixosConfigurations {
      inherit inputs;
      inherit (nixpkgs) lib;
    };

    devShells = forAllSystems (pkgs: {
      default = import ./shell.nix pkgs;
    });
  };
}
