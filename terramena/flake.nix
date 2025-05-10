{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
  };

  outputs = inputs @ {
    nixpkgs,
    systems,
    flake-parts,
    rust-overlay,
    crane,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;

      perSystem = {
        self',
        system,
        ...
      }: let
        pkgs = nixpkgs.legacyPackages.${system}.extend rust-overlay.overlays.default;
        toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        manifest = pkgs.lib.importTOML ./Cargo.toml;

        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
        craneArgs = {
          pname = manifest.package.name;
          version = manifest.package.version;
          src = craneLib.cleanCargoSource ./.;

          buildInputs = with pkgs; [];
          nativeBuildInputs = with pkgs; [pkg-config];
          runtimeDependencies = with pkgs; [];
        };
      in {
        packages = {
          default =
            craneLib.buildPackage (craneArgs
              // {cargoArtifacts = craneLib.buildDepsOnly craneArgs;});
        };

        checks.default = self'.packages.default;

        devShells.default = craneLib.devShell {
          inputsFrom = [self'.packages.default];
          packages = with toolchain.availableComponents; [
            rust-src
            rust-analyzer
            rustfmt
            clippy
          ];

          # Uncomment to include dynamic libraries
          # LD_LIBRARY_PATH = lib.makeLibraryPath (
          #   __concatMap (d: d.runtimeDependencies) (__attrValues self'.checks)
          # );
        };
      };
    };
}
