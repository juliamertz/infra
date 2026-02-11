{
  pkgs,
  kubenix,
  ...
}: let
  inherit (pkgs) lib;
  inherit (pkgs.stdenv.hostPlatform) system;

  output = kubenix.evalModules.${system} {
    module = {...}: {imports = [./modules];};
    specialArgs = {
      util = import ./util.nix {inherit pkgs lib;};
      crds = import ./types;
    };
  };
in
  output
