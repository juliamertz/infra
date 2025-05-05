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

            TERRAFORM_DIR=''${DIRENV_DIR#-}/terraform

            $TERRAFORM_DIR/hcloud_nixos/scripts/local-rebuild
          '';

        tofu = 
            # sh
            ''
              TERRAFORM_DIR=''${DIRENV_DIR#-}/terraform
              ${lib.getExe opentofu} -chdir=$TERRAFORM_DIR $@
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
