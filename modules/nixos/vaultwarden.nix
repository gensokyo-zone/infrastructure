{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkOptionDefault;
  inherit (lib.attrsets) attrNames filterAttrs mapAttrs' nameValuePair;
  inherit (lib.strings) concatMapStringsSep;
  cfg = config.services.vaultwarden;
  RuntimeDirectory = "bitwarden_rs";
  secretsFile = "secrets.env";
in {
  options.services.vaultwarden = with lib.types; {
    port = mkOption {
      type = port;
      default = 8222;
    };
    websocketPort = mkOption {
      type = nullOr port;
      default = null;
    };
    databaseUrlPath = mkOption {
      type = nullOr str;
      default = null;
    };
    adminTokenPath = mkOption {
      type = nullOr str;
      default = null;
    };
    smtpPasswordPath = mkOption {
      type = nullOr str;
      default = null;
    };
  };
  config.services.vaultwarden = {
    config = {
      DATA_FOLDER = mkOptionDefault "/var/lib/bitwarden_rs";
      WEB_VAULT_ENABLED = mkOptionDefault true;
      ROCKET_ENV = mkOptionDefault "production";
      ROCKET_ADDRESS = mkOptionDefault "::1";
      ROCKET_PORT = mkOptionDefault cfg.port;
      WEBSOCKET_ENABLED = mkOptionDefault (cfg.websocketPort != null);
      WEBSOCKET_ADDRESS = mkOptionDefault "::1";
      WEBSOCKET_PORT = mkIf (cfg.websocketPort != null) cfg.websocketPort;
    };
  };
  config.systemd.services.vaultwarden = let
    filterNullAttrs = filterAttrs (_: v: v != null);
    secretPaths' = {
      DATABASE_URL = cfg.databaseUrlPath;
      ADMIN_TOKEN = cfg.adminTokenPath;
      SMTP_PASSWORD = cfg.smtpPasswordPath;
    };
    secretPaths = filterNullAttrs secretPaths';
    hasSecrets = secretPaths != {};
    mkPrintSecret = key: let
      path = "${key}_PATH";
    in ''
      if [[ -n ''${${path}-} ]]; then
        printf "${key}=$(cat ''${${path}})\\n" >> $RUNTIME_DIRECTORY/${secretsFile}
      fi
    '';
    prepSecrets = pkgs.writeShellScript "vaultwarden-secrets.sh" ''
      set -eu

      printf "" > $RUNTIME_DIRECTORY/${secretsFile}
      chmod 0640 $RUNTIME_DIRECTORY/${secretsFile}

      ${concatMapStringsSep "\n" mkPrintSecret (attrNames secretPaths')}
    '';
  in
    mkIf cfg.enable {
      environment = mkIf hasSecrets (mapAttrs' (key: nameValuePair "${key}_PATH") secretPaths);
      serviceConfig = {
        inherit RuntimeDirectory;
        EnvironmentFile = mkIf hasSecrets [
          "-/run/${RuntimeDirectory}/${secretsFile}"
        ];
        ExecStartPre = mkIf hasSecrets [
          "${prepSecrets}"
        ];
      };
    };
}
