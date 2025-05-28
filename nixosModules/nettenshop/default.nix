{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.nettenshop;

  revision = "5a0432bec7d21ef5bd0e136d5a7131ae4281904b";
  lightspeed-dhl-adapter =
    (builtins.getFlake "github:juliamertz/lightspeed-dhl-adapter/${revision}")
    .packages
    .${pkgs.system}
    .default;
in {
  options.services.nettenshop = with lib; {
    enable = mkEnableOption "nettenshop";
    serviceName = mkOption {
      type = types.str;
      default = "lightspeed-dhl-adapter";
    };
    package = mkOption {
      type = types.package;
      default = lightspeed-dhl-adapter;
    };
    openFirewall = mkEnableOption "firewall";
    port = mkOption {
      type = types.port;
      default = 5010;
    };
    stateDir = mkOption {
      type = types.path;
      default = "/etc/lightspeed-dhl";
    };
    sopsFile = mkOption {
      type = types.path;
      default = null;
    };
    user = mkOption {
      type = types.str;
      default = "nettenshop";
    };
    group = mkOption {
      type = types.str;
      default = "nettenshop";
    };
    extraUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = mkDoc ''
        Extra users to add to the default group for this service
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [cfg.port];

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group}"
      "L ${cfg.stateDir}/config.toml 0750 ${cfg.user} ${cfg.group} - ${config.sops.templates."${cfg.serviceName}-config.toml".path}"
    ];

    systemd.services.${cfg.serviceName} = {
      description = "${cfg.serviceName} service";
      wantedBy = ["multi-user.target"];

      environment = {
        GO_LOG = "info";
        ENVIRONMENT = "production";
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;

        WorkingDirectory = cfg.stateDir;
        ExecStart = "${lib.getExe cfg.package} ${cfg.stateDir}/config.toml";

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
        ReadWritePaths = [cfg.stateDir];
        RemoveIPC = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
      };
    };

    users.groups.${cfg.group} = {};
    users.users =
      {
        ${cfg.user} = {
          inherit (cfg) group;
          isSystemUser = true;
        };
      }
      // lib.genAttrs cfg.extraUsers (_: {extraGroups = [cfg.group];});

    sops.secrets =
      lib.genAttrs [
        "dhl_accountId"
        "dhl_userId"
        "dhl_apiKey"
        "lightspeed_cluster"
        "lightspeed_key"
        "lightspeed_secret"
        "lightspeed_frontend"
        "lightspeed_clusterId"
        "lightspeed_shopId"
      ] (key: {
        owner = cfg.user;
        sopsFile = cfg.sopsFile;
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
          Frontend  = "${lightspeed_frontend}"
          Cluster   = "${lightspeed_cluster}"
          Key       = "${lightspeed_key}"
          Secret    = "${lightspeed_secret}"
          ClusterId = "${lightspeed_clusterId}"
          ShopId    = "${lightspeed_shopId}"

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
          PollingInterval = 15
        '';
    };
  };
}
