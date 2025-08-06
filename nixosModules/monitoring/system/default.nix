{
  lib,
  config,
  ...
}: let
  cfg = config.services.monitoring.system;
in {
  options = with lib; {
    services.monitoring.system = {
      enable = mkEnableOption "Enable prometheus system metric exporters";

      units = mkOption {
        type = types.listOf types.str;
        default = [];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters = {
      node = {
        enable = true;
        enabledCollectors = ["logind" "systemd"];
      };

      systemd = {
        enable = true;
        extraFlags = [
          "--systemd.collector.enable-restart-count"
          "--systemd.collector.enable-ip-accounting"
          "--systemd.collector.unit-include=${cfg.units |> map (v: v + ".service") |> lib.concatStringsSep "|"}"
        ];
      };

      process = {
        enable = true;
        settings.process_names = [
          # Remove nix store path from process name
          {
            name = "{{.Matches.Wrapped}} {{ .Matches.Args }}";
            cmdline = ["^/nix/store[^ ]*/(?P<Wrapped>[^ /]*) (?P<Args>.*)"];
          }
        ];
      };
    };
  };
}
