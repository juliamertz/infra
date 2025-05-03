{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.nettenshop;

  revision = "1b12d66579aa536836fd87feef3d29acb80d650d";
  lightspeed-dhl-adapter =
    (builtins.getFlake "github:juliamertz/lightspeed-dhl-adapter/${revision}?dir=nix")
    .packages
    .${pkgs.system}
    .default;
in {
  options.services.nettenshop = with lib; {
    serviceName = mkOption {
      type = types.str;
      default = "lightspeed-dhl-adapter";
    };
    package = mkOption {
      type = types.package;
      default = lightspeed-dhl-adapter;
    };
    port = mkOption {
      type = types.port;
      default = 5010;
    };
    stateDir = mkOption {
      type = types.path;
      default = "/etc/lightspeed-dhl";
    };
    configPath = mkOption {
      type = types.path;
      default = config.sops.templates."${cfg.serviceName}-config.toml".path;
    };
    user = mkOption {
      type = types.str;
      default = "valnetten";
    };
    group = mkOption {
      type = types.str;
      default = "valnetten";
    };
  };

  config = {
    systemd.tmpfiles.rules = ["d ${cfg.stateDir} 0770 ${cfg.user} ${cfg.group}"];

    systemd.services.${cfg.serviceName} = {
      description = "${cfg.serviceName} service";
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;

        WorkingDirectory = cfg.stateDir;
        ExecStart = "${lib.getExe cfg.package} ${cfg.configPath}";

        KeyringMode = "private";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateMounts = "yes";
        PrivateTmp = "yes";
        ProtectControlGroups = true;
        ProtectHome = "yes";
        ProtectHostname = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        ReadWritePaths = [cfg.stateDir cfg.configPath];
        RemoveIPC = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
      };
    };

    users.groups.${cfg.group} = {};
    users.users.${cfg.user} = {
      inherit (cfg) group;
      isSystemUser = true;
    };

    sops.secrets =
      lib.genAttrs [
        "dhl_accountId"
        "dhl_userId"
        "dhl_apiKey"
        "lightspeed_cluster"
        "lightspeed_key"
        "lightspeed_secret"
        "lightspeed_frontend"
      ] (key: {
        owner = cfg.user;
        sopsFile = ../../../secrets/valnetten.yaml;
        inherit key;
      });

    sops.templates."${cfg.serviceName}-config.toml" = {
      owner = cfg.user;
      restartUnits = ["${cfg.serviceName}.service"];
      content = with config.sops.placeholder;
      # toml
        ''
          [DHL]
          AccountId = "${dhl_accountId}"
          UserId    = "${dhl_userId}"
          ApiKey    = "${dhl_apiKey}"

          [Lightspeed]
          Frontend = "${lightspeed_frontend}"
          Cluster  = "${lightspeed_cluster}"
          Key      = "${lightspeed_key}"
          Secret   = "${lightspeed_secret}"

          [CompanyInfo]
          Name         = "Nettenshop"
          Street       = "Rondven"
          City         = "Maarheeze"
          PostalCode   = "6026PX"
          CountryCode  = "NL"
          Number       = "41"
          Addition     = "A"
          Email        = "info@nettenshop.nl"
          PhoneNumber  = "+31402901155"
          PersonalNote = "Uw bestelling bij nettenshop.nl is met DHL onderweg! Via de bijgevoegde link kunt u uw pakket volgen. Mocht u vragen hebben, neem dan contact met ons op via de klantenservice. Met vriendelijke groet, Team Nettenshop.nl"

          [Options]
          DryRun          = false
          Port            = ${builtins.toString cfg.port}
          Environment     = "production"
          Debug           = false
          PollingInterval = 15
        '';
    };
  };
}
