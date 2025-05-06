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
            export TERRAFORM_DIR=''${DIRENV_DIR#-}/terraform
            export SSH_ADDRESS="$(tofu output ip_$PROFILE | xargs)"
            export SSH_USER=root

            $TERRAFORM_DIR/hcloud_nixos/scripts/local-rebuild
          '';

        conn =
          # sh
          ''
            ip=$(tofu output "ip_$1" | xargs)
            echo $ip
            ssh root@$ip
          '';
      };
  }
