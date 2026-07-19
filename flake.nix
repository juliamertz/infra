{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-cross.url = "github:nixos/nixpkgs/90ade7da38aa49c2e2693a04a44662a0e61530e9";
    systems.url = "github:nix-systems/default";
    filter.url = "github:numtide/nix-filter";
    kubenix.url = "github:hall/kubenix";
    sops.url = "github:Mic92/sops-nix";
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-cross,
    kubenix,
    systems,
    crane,
    filter,
    rust-overlay,
    ...
  }: let
    inherit (nixpkgs) lib;
    overlays = [
      (import rust-overlay)
    ];
    mkCraneLib = pkgs': (crane.mkLib pkgs').overrideToolchain (p: p.rust-bin.stable."1.90.0".default);

    forAllSystems = fun:
      lib.genAttrs (import systems) (system:
        fun (import nixpkgs {
          inherit system;
          inherit overlays;
          config.allowUnfree = true;
        }));
  in {
    packages = forAllSystems ({
      pkgs,
      lib,
      ...
    }: let
      kubelib = import ./kubernetes/util.nix {inherit pkgs lib kubenix;};
      # packages = self.packages.${stdenv.hostPlatform.system};
      mkCluster = imports: kubelib.evalKubenix imports;
      personal = mkCluster [./kubernetes/clusters/personal.nix];
      thenewnorm = mkCluster [./kubernetes/clusters/thenewnorm.nix];
      mc = mkCluster [./kubernetes/modules/apps/minecraft-server];
    in {
      personal-crds = personal.crds;
      personal = personal.resources;

      thenewnorm-crds = thenewnorm.crds;
      thenewnorm = thenewnorm.resources;

      minecraft = mc.resources;

      renovateConfig = pkgs.callPackage ./renovate.nix {
        packages = {inherit personal;};
      };
    });

    devShells = forAllSystems (pkgs: let
      inherit (pkgs.stdenv.hostPlatform) system;

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

      craneLib = mkCraneLib pkgs;

      k8s-diff = pkgs.writeShellScript "k8s-diff" ''
        ${lib.getExe pkgs.colordiff} --nobanner -N -u -I ' kubenix/' -I ' generation: ' "$@"
      '';
      k8s-build = pkgs.writeShellScriptBin "k8s-build" ''
        nix build "$1" -o result && cat result | vals eval -f - > resources.json
      '';
      kubectl = lib.getExe pkgs.kubectl;
      k8s-apply = pkgs.writeShellScriptBin "k8s-apply" ''
        k8s-build "$1" && ${kubectl} apply --server-side --force-conflicts -f resources.json
      '';
      k8s-diffcmd = pkgs.writeShellScriptBin "k8s-diff" ''
        k8s-build "''${1:-personal}" \
          && KUBECTL_EXTERNAL_DIFF='${k8s-diff}' ${kubectl} diff --server-side --force-conflicts -f resources.json
      '';

      renovate-sync = pkgs.writeShellScriptBin "renovate-sync" ''
        ${lib.getExe pkgs.jq} . ${self.packages.${system}.renovateConfig} > renovate.json
      '';
    in {
      default = craneLib.devShell {
        packages = [
          pkgs.rust-analyzer
          pkgs.jq
          pkgs.yq
          pkgs.treefmt
          pkgs.alejandra
          # pkgs.packer
          pkgs.hcloud
          pkgs.talosctl
          pkgs.nix-eval-jobs
          pkgs.awscli
          pkgs.wget
          pkgs.vals
          k8s-build
          k8s-apply
          k8s-diffcmd
          renovate-sync
          hcloud-upload-image
          tofu
        ];
      };
    });
  };
}
