{
  pkgs,
  config,
  ...
}: let
  lokiPort = config.services.loki.configuration.server.http_listen_port;
in {
  services.alloy = {
    enable = true;
    configPath = "/etc/alloy/client.alloy";
  };

  environment.etc."alloy/client.alloy" = {
    mode = "0644";
    text =
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
