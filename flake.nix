{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    srvos = {
      url = "github:nix-community/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    nixosConfigurations = import ./machines {
      inherit inputs;
      inherit (nixpkgs) lib;
    };

    devShells.default =
      forAllSystems (pkgs:
        import ./shell.nix {inherit pkgs;});
  };
}
