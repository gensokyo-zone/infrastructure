{ config, lib, pkgs, ... }:

let
  inherit (lib) types mkIf mkOption mkEnableOption mkPackageOption mkDefault;

  cfg = config.services.gatus;

  configFile = pkgs.writeText "gatus-config.yml" (builtins.toJSON (cfg.settings
    // {
      endpoints = builtins.attrValues cfg.settings.endpoints;
    }));
in {
  options.services.gatus = {
    enable = mkEnableOption "a developer-oriented service status page";

    package = mkPackageOption pkgs "gatus" { };

    user = mkOption {
      type = types.str;
      default = "gatus";
    };

    group = mkOption {
      type = types.str;
      default = "gatus";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
    };

    # https://github.com/TwiN/gatus#configuration

    settings = {
      debug = mkEnableOption "debug logs";

      metrics = mkEnableOption "expose metrics at /metrics";

      storage = {
        path = mkOption { type = types.path; };
        type = mkOption { type = types.enum [ "memory" "sqlite" "postgres" ]; };
        caching = mkEnableOption "write-through caching";
      };

      endpoints = mkOption {
        type = types.attrsOf (types.submodule ({ name, ... }: {
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
            url = mkOption { type = types.str; };
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
                freeformType = (pkgs.formats.yaml { }).type;
              };
              default = { };
              description = ''
                Request headers.
              '';
            };
            dns = mkOption {
              type = types.nullOr (types.submodule {
                options = {
                  query-type = mkOption {
                    type = types.enum [ "A" "AAAA" "CNAME" "MX" "NS" ];
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
                  failure-threshold = mkOption { type = types.ints.positive; };
                  success-threshold = mkOption { type = types.ints.positive; };
                  send-on-resolved = mkEnableOption
                    "sending a notification once a triggered alert is marked as solved";
                  description = mkOption { type = types.str; };
                };
              });
              default = [ ];
            };
            client = mkOption {
              type = types.submodule {
                freeformType = (pkgs.formats.yaml { }).type;
              };
              default = { };
              description = ''
                [https://github.com/TwiN/gatus#client-configuration](Client configuration).
              '';
            };
            ui = {
              hide-hostname =
                mkEnableOption "hiding the hostname in the result";
              hide-url = mkEnableOption "hiding the URL in the results";
              dont-resolve-failed-conditions =
                mkEnableOption "resolving failed conditions for the UI";
              badge.response-time.thresholds = mkOption {
                type = types.listOf types.ints.positive;
                default = [ 50 200 300 500 750 ];
                description = ''
                  List of response time thresholds. Each time a threshold is reached,
                  the badge has a different color.
                '';
              };
            };
          };
          config = { name = mkDefault name; };
        }));
        default = { };
      };
      alerting = mkOption {
        type = types.submodule { freeformType = (pkgs.formats.yaml { }).type; };
        default = { };
        description = ''
          [https://github.com/TwiN/gatus#alerting](Alerting configuration).
        '';
      };
      security = mkOption {
        type = types.nullOr
          (types.submodule { freeformType = (pkgs.formats.yaml { }).type; });
        default = null;
        description = ''
          [https://github.com/TwiN/gatus#security](Security configuration).
        '';
      };
      disable-monitoring-lock = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to disable the monitoring lock";
      };
      skip-invalid-config-update = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to ignore invalid configuration update";
      };
      web = {
        address = mkOption {
          type = types.str;
          default = "0.0.0.0";
          description = "Address to listen on";
        };
        port = mkOption {
          type = types.port;
          default = 8080;
          description = "Port to listen on";
        };
        tls = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              certificate-file = mkOption {
                type = types.nullOr types.path;
                default = null;
                description =
                  "Optional public certificate file for TLS in PEM format";
              };
              private-key-file = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "Optional private key file for TLS in PEM format";
              };
            };
          });
          default = null;
        };
      };
      ui = {
        title = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Title of the document";
        };
        description = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Meta description for the page";
        };
        header = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Header at the top of the dashboard";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.gatus = {
      description = "Automated developer-oriented status page";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment.GATUS_CONFIG_PATH = "${configFile}";

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "gatus";
        LogsDirectory = "gatus";
        EnvironmentFile =
          mkIf (cfg.environmentFile != null) cfg.environmentFile;

        AmbientCapabilities = "CAP_NET_RAW"; # needed for ICMP probes
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
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        UMask = "0077";

        ExecStart = "${cfg.package}/bin/gatus";
      };
    };

    users.groups = mkIf (cfg.group == "gatus") { ${cfg.group} = { }; };

    users.users = mkIf (cfg.user == "gatus") {
      ${cfg.user} = {
        inherit (cfg) group;
        description = "gatus service user";
        isSystemUser = true;
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ christoph-heiss ];
}