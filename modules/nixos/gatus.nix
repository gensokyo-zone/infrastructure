{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkForce;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) length unique;
  inherit (lib) types;
  cfg = config.services.gatus;

  endpointModule = {name, lib, ...}: let
    inherit (lib) types;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkOptionDefault;
  in {
    options = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to monitor the endpoint.
        '';
      };
      name = mkOption {
        type = types.str;
        description = ''
          Name of the endpoint. Can be anything.
          Defaults to attribute name in `endpoints`.
        '';
      };
      group = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Group name. Used to group multiple endpoints together on the dashboard.
          See [https://github.com/TwiN/gatus#endpoint-groups](Endpoint groups).
        '';
      };
      url = mkOption {type = types.str;};
      method = mkOption {
        type = types.enum [
          "GET"
          "HEAD"
          "POST"
          "PUT"
          "DELETE"
          "CONNECT"
          "OPTIONS"
          "TRACE"
          "PATCH"
        ];
        default = "GET";
        description = ''
          Request method.
        '';
      };
      conditions = mkOption {
        type = types.listOf types.str;
        description = ''
          Conditions used to determine the health of the endpoint.
          See [https://github.com/TwiN/gatus#conditions](Conditions).
        '';
      };
      interval = mkOption {
        type = types.str;
        default = "60s";
        description = ''
          Duration to wait between every status check.
        '';
      };
      graphql =
        mkEnableOption "wrapping the body in a query param for GraphQL";
      body = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Request body.
        '';
      };
      headers = mkOption {
        type = types.submodule {
          freeformType = (pkgs.formats.yaml {}).type;
        };
        default = {};
        description = ''
          Request headers.
        '';
      };
      dns = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            query-type = mkOption {
              type = types.enum ["A" "AAAA" "CNAME" "MX" "NS"];
              description = ''
                Query type (e.g. MX)
              '';
            };
            query-name = mkOption {
              type = types.str;
              description = ''
                Query name (e.g. example.com)
              '';
            };
          };
        });
        default = null;
      };
      ssh = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            username = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                SSH username
              '';
            };
            password = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                SSH password
              '';
            };
          };
        });
        default = null;
      };
      alerts = mkOption {
        type = types.listOf (types.submodule {
          options = {
            type = mkOption {
              type = types.enum [
                "custom"
                "discord"
                "email"
                "github"
                "gitlab"
                "googlechat"
                "gotify"
                "matrix"
                "mattermost"
                "messagebird"
                "ntfy"
                "opsgenie"
                "pagerduty"
                "pushover"
                "slack"
                "teams"
                "telegram"
                "twilio"
              ];
            };
            enabled = mkOption {
              type = types.bool;
              default = true;
            };
            failure-threshold = mkOption {type = types.ints.positive;};
            success-threshold = mkOption {type = types.ints.positive;};
            send-on-resolved =
              mkEnableOption
              "sending a notification once a triggered alert is marked as solved";
            description = mkOption {type = types.str;};
          };
        });
        default = [];
      };
      client = mkOption {
        type = types.submodule {
          freeformType = (pkgs.formats.yaml {}).type;
        };
        default = {};
        description = ''
          [https://github.com/TwiN/gatus#client-configuration](Client configuration).
        '';
      };
      ui = {
        hide-conditions =
          mkEnableOption "hiding the condition results on the UI";
        hide-hostname =
          mkEnableOption "hiding the hostname in the result";
        hide-url = mkEnableOption "hiding the URL in the results";
        dont-resolve-failed-conditions =
          mkEnableOption "resolving failed conditions for the UI";
        badge.response-time.thresholds = mkOption {
          type = types.listOf types.ints.positive;
          default = [50 200 300 500 750];
          description = ''
            List of response time thresholds. Each time a threshold is reached,
            the badge has a different color.
          '';
        };
      };
    };
    config = {
      name = mkOptionDefault name;
    };
  };
in {
  options.services.gatus = let
    settingsModule = { ... }: {
      options = with types; {
        /*endpoints = mkOption {
          type = listOf unspecified;
          #type = attrsOf (submodule endpointModule);
          #default = {};
        };*/
      };
    };
  in with types; {
    hardening = {
      enable = mkEnableOption "sandbox and harden service";
      icmp.enable = mkEnableOption "needed for ICMP probes";
    };
    user = mkOption {
      type = nullOr str;
      default = null;
    };

    endpoints = mkOption {
      type = attrsOf (submodule endpointModule);
      default = {};
    };

    settings = mkOption {
      type = submodule settingsModule;
    };
  };

  config = let
    conf.assertions = let
      endpointNames = map (endpoint: endpoint.name) (attrValues cfg.endpoints);
    in [
      {
        assertion = length (unique endpointNames) == length endpointNames;
        message = "Gatus endpoint names must be unique";
      }
    ];
    conf.systemd.services.gatus = {
      serviceConfig = mkMerge [
        serviceConfig
        (mkIf cfg.hardening.enable serviceConfig'hardening)
      ];
    };
    serviceConf = {
      services.gatus.settings.endpoints = mkIf (cfg.endpoints != {}) (attrValues cfg.endpoints);
    };
    serviceConfig = {
      User = mkIf (cfg.user != null) (mkForce cfg.user);

      AmbientCapabilities = mkIf cfg.hardening.icmp.enable ["CAP_NET_RAW"];
    };
    serviceConfig'hardening = {
      DevicePolicy = "closed";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateMounts = true;
      PrivateTmp = true;
      ProcSubset = "pid";
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      RemoveIPC = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      UMask = "0077";
    };
  in mkMerge [
    (mkIf cfg.enable conf)
    serviceConf
  ];
}
