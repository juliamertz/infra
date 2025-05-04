{
  pkgs,
  lib,
  ...
}: let
  writeScripts = lib.mapAttrsToList (name: value: pkgs.writeShellScriptBin name value);
in
  pkgs.mkShell {
    packages = with pkgs;
      [
        opentofu
        alejandra
        treefmt
      ]
      ++ writeScripts {
        nixos-deploy =
          # sh
          ''
            export FLAKE="."
            export PROFILE="$1"
            export SSH_ADDRESS="$(tofu -chdir=terraform output "ip_$PROFILE" | xargs)"
            export SSH_USER=root

            ./terraform/hcloud_nixos/scripts/local-rebuild
          '';

        setup-infra =
          # sh
          ''
            ${lib.getExe opentofu} -chdir=terraform apply
          '';
      };
  }
