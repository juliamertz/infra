{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.monitoring.logs;
in {
  options = with lib; {
    services.monitoring.logs = {
      enable = mkEnableOption "Enable Journald log exporting";

      endpoint = mkOption {
        type = types.str;
        default = null;
      };

      units = mkOption {
        type = types.listOf types.str;
        default = ["fail2ban"];
      };
    };
  };

  config = {
    services.alloy = {
      enable = true;
      configPath =
        pkgs.writeText "config.alloy"
        # hcl
        ''
          loki.relabel "journal" {
            forward_to = []

            rule {
              source_labels = ["__journal__systemd_unit"]
              regex         = "(${lib.concatStringsSep "|" cfg.units})\\.service"
              action        = "keep"
            }

            rule {
              source_labels = ["__journal__systemd_unit"]
              target_label  = "unit"
            }
          }

          loki.source.journal "read"  {
            forward_to    = [loki.write.endpoint.receiver]
            relabel_rules = loki.relabel.journal.rules
            labels        = {component = "loki.source.journal"}
          }

          loki.write "endpoint" {
            endpoint {
              url = "${cfg.endpoint}"
            }
          }
        '';
    };
  };
}
