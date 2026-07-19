{
  pkgs,
  config,
  ...
}: let
  lokiPort = config.services.loki.configuration.server.http_listen_port;
in {
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
            url = "http://0.0.0.0:${toString lokiPort}/loki/api/v1/push"
          }
        }
      '';
  };
}
# rule {
#   source_labels = ["__journal__systemd_unit"]
#   regex         = "(nginx|docker|ssh)\.service"
#   action        = "keep"
# }

