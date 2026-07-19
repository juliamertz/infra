{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    filter.url = "github:numtide/nix-filter";
    sops.url = "github:Mic92/sops-nix";
  };

  outputs = {
    nixpkgs,
    systems,
    ...
  }: let
    inherit (nixpkgs) lib;
    forAllSystems = fun:
      lib.genAttrs (import systems) (system:
        fun (import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }));
  in {
    devShells = forAllSystems (pkgs: let
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
    in {
      default = pkgs.mkShell {
        packages = [
          pkgs.rust-analyzer
          pkgs.jq
          pkgs.yq
          pkgs.treefmt
          pkgs.alejandra
          pkgs.hcloud
          pkgs.talosctl
          pkgs.nix-eval-jobs
          pkgs.awscli
          pkgs.wget
          pkgs.vals
          hcloud-upload-image
          tofu
        ];
      };
    });
  };
}
