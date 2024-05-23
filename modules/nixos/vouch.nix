{
  config,
  utils,
  pkgs,
  lib,
  ...
}: let
  inherit
    (lib)
    mkIf
    mkMerge
    mkDefault
    mkOptionDefault
    mkOption
    mkPackageOption
    mkEnableOption
    types
    getExe
    ;
  nixosConfig = config;
  cfg = config.services.vouch-proxy;
  settingsFormat = pkgs.formats.json {};
in {
  options.services.vouch-proxy = with types; {
    enable = mkEnableOption "vouch";
    package = mkPackageOption pkgs "vouch-proxy" { };
    user = mkOption {
      type = str;
      default = "vouch-proxy";
    };
    group = mkOption {
      type = str;
      default = "vouch-proxy";
    };
    authUrl = mkOption {
      type = str;
      default = config.services.kanidm.serverSettings.origin;
    };
    domain = mkOption {
      type = str;
      default = config.networking.domain;
    };
    url = mkOption {
      type = str;
      default = "https://${cfg.domain}";
    };
    enableSettingsSecrets = mkEnableOption "genJqSecretsReplacementSnippet";
    settings = let
      settingsModule = {...}: {
        freeformType = settingsFormat.type;
        options = {
          vouch = {
            cookie = {
              domain = mkOption {
                type = nullOr str;
                default = nixosConfig.networking.domain;
              };
              secure = mkOption {
                type = bool;
                default = true;
              };
            };
            port = mkOption {
              type = port;
              default = 30746;
            };
            listen = mkOption {
              type = nullOr str;
              default = "127.0.0.1";
            };
            allowAllUsers = mkOption {
              type = bool;
              default = true;
            };
          };
          oauth = {
            auth_url = mkOption {
              type = str;
              default = "${cfg.authUrl}/ui/oauth2";
            };
            token_url = mkOption {
              type = str;
              default = "${cfg.authUrl}/oauth2/token";
            };
            user_info_url = mkOption {
              type = str;
              default = "${cfg.authUrl}/oauth2/openid/vouch/userinfo";
            };
            scopes = mkOption {
              type = listOf str;
              default = ["openid" "email" "profile"];
            };
            callback_url = mkOption {
              type = str;
              default = "${cfg.url}/auth";
            };
            provider = mkOption {
              type = nullOr str;
              default = "oidc";
            };
            code_challenge_method = mkOption {
              type = str;
              default = "S256";
            };
            client_id = mkOption {
              type = str;
              default = "vouch";
            };
          };
        };
      };
    in
      mkOption {
        type = submodule settingsModule;
        default = {};
      };
    extraSettings = mkOption {
      inherit (settingsFormat) type;
      default = {};
    };
    settingsPath = mkOption {
      type = path;
    };
  };
  config = let
    recursiveMergeAttrs = listOfAttrsets: lib.fold (attrset: acc: lib.recursiveUpdate attrset acc) {} listOfAttrsets;
    settings = recursiveMergeAttrs [
      cfg.settings
      cfg.extraSettings
    ];
    settingsPath =
      if cfg.enableSettingsSecrets
      then "/run/vouch-proxy/vouch-config.json"
      else settingsFormat.generate "vouch-config.json" settings;
  in
    mkMerge [
      {
        services.vouch-proxy = {
          settingsPath = mkOptionDefault settingsPath;
        };
      }
      (mkIf cfg.enable {
        networking.firewall.interfaces.local = {
          allowedTCPPorts = mkIf (cfg.settings.vouch.listen != "127.0.0.1") [
            cfg.settings.vouch.port
          ];
        };
        systemd.services.vouch-proxy = {
          description = "Vouch-proxy";
          after = ["network.target"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            ExecStartPre = let
              preprocess = pkgs.writeShellScript "vouch-proxy-prestart" (
                utils.genJqSecretsReplacementSnippet settings cfg.settingsPath
              );
            in
              mkIf cfg.enableSettingsSecrets [
                "${preprocess}"
              ];
            ExecStart = [
              "${getExe cfg.package} -config ${cfg.settingsPath}"
            ];
            Restart = "on-failure";
            RestartSec = mkDefault 5;
            WorkingDirectory = "/var/lib/vouch-proxy";
            StateDirectory = "vouch-proxy";
            RuntimeDirectory = "vouch-proxy";
            User = cfg.user;
            Group = cfg.group;
            StartLimitBurst = mkDefault 3;
          };
        };

        users.users.${cfg.user} = {
          inherit (cfg) group;
          isSystemUser = true;
        };

        users.groups.${cfg.group} = {};
      })
    ];
}
