{
  config,
  lib,
  utils,
  pkgs,
  ...
}: let
  inherit (utils) escapeSystemdPath;
  inherit (lib.options) mkOption mkEnableOption mkPackageOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault mkDefault;
  inherit (lib.attrsets) mapAttrs' nameValuePair;
  inherit (lib.lists) optional isList imap0;
  inherit (lib.strings) optionalString concatStringsSep;
  inherit (lib.meta) getExe;
  cfg = config.services.barcodebuddy-scanner;
  toEnvName = key: "BBUDDY_" + key;
  toEnvValue = value:
    if value == true
    then "true"
    else if value == false
    then "false"
    else if isList value
    then concatStringsSep ";" (imap0 (i: v: "${toString i}=${toEnvValue v}") value)
    else toString value;
  toEnvPair = key: value: nameValuePair (toEnvName key) (toEnvValue value);
in {
  options.services.barcodebuddy-scanner = with lib.types; {
    enable = mkEnableOption "Barcode Buddy scanner";
    package = mkPackageOption pkgs "barcodebuddy-scanner" {
      example = "pkgs.barcodebuddy-scanner-python";
    };
    inputDevice = mkOption {
      type = nullOr path;
      default = null;
      example = "/dev/input/event6";
    };
    serverAddress = mkOption {
      type = nullOr str;
      example = "https://your.bbuddy.url/api/";
    };
    apiKeyPath = mkOption {
      type = nullOr path;
    };
    user = mkOption {
      type = str;
    };
    scanCommand = mkOption {
      type = nullOr path;
      default = null;
    };
    udevMatchRules = mkOption {
      type = nullOr (listOf str);
      default = null;
      example = [
        ''ATTRS{idVendor}=="1abc"''
      ];
    };
  };

  config = let
    scannerConfig.services.barcodebuddy-scanner = {
      inputDevice = mkIf (cfg.udevMatchRules != null) (
        mkDefault "/dev/barcodebuddy-scanner"
      );
      apiKeyPath = mkIf (cfg.serverAddress == null) (
        mkOptionDefault null
      );
    };
    localBbuddyConfig = {
      services.barcodebuddy-scanner = {
        serverAddress = mkOptionDefault null;
        user = mkOptionDefault "barcodebuddy";
      };
      systemd.services.barcodebuddy-scanner = let
        inherit (config.services) barcodebuddy;
        services =
          ["phpfpm-barcodebuddy.service"]
          ++ optional barcodebuddy.screen.enable "barcodebuddy-websocket.service";
      in
        mkIf cfg.enable {
          wantedBy = services;
          bindsTo = services;
          after = services;
          environment = mapAttrs' toEnvPair barcodebuddy.settings;
        };
    };

    # https://github.com/Forceu/barcodebuddy/blob/master/example/bbuddy-grabInput.conf
    conf.systemd.services.barcodebuddy-scanner = let
      RuntimeDirectory = "barcodebuddy-scanner";
      apiKeyFile = "apikey.env";
      prepKeyEnvironment = pkgs.writeShellScript "barcodebuddy-scanner-apikey.sh" ''
        set -eu

        printf "API_KEY=$(cat $API_KEY_PATH)\\n" > $RUNTIME_DIRECTORY/${apiKeyFile}
      '';
    in {
      wantedBy = [
        "multi-user.target"
      ];
      environment = mkMerge [
        (mkIf (cfg.serverAddress != null) {
          SERVER_ADDRESS = cfg.serverAddress;
        })
        (mkIf (cfg.scanCommand != null) {
          BARCODE_COMMAND = cfg.scanCommand;
        })
        (mkIf (cfg.apiKeyPath != null) {
          API_KEY_PATH = cfg.apiKeyPath;
        })
      ];
      unitConfig = {
        Description = "Grab barcode scans for barcode buddy";
        ConditionPathExists = mkIf (cfg.inputDevice != null) [
          cfg.inputDevice
        ];
      };
      serviceConfig = {
        inherit RuntimeDirectory;
        Type = "exec";
        ExecStart = [
          (getExe cfg.package + optionalString (cfg.inputDevice != null) " ${cfg.inputDevice}")
        ];
        ExecStartPre = mkIf (cfg.apiKeyPath != null) [
          "${prepKeyEnvironment}"
        ];
        EnvironmentFile = mkIf (cfg.apiKeyPath != null) [
          "-/run/${RuntimeDirectory}/${apiKeyFile}"
        ];
        Restart = "on-failure";
        User = cfg.user;
      };
    };
    conf.services.udev.extraRules = let
      rules =
        [
          ''SUBSYSTEM=="input"''
          ''ACTION=="add"''
          ''KERNEL=="event*"''
        ]
        ++ cfg.udevMatchRules
        ++ [
          ''SYMLINK+="barcodebuddy-scanner"''
          ''OWNER="${cfg.user}"''
          ''MODE="0600"''
          ''TAG+="systemd"''
          ''ENV{SYSTEMD_WANTS}="barcodebuddy-scanner.service"''
        ];
      rulesLine = concatStringsSep ", " rules;
    in
      mkIf (cfg.udevMatchRules != null) rulesLine;
  in
    mkMerge [
      scannerConfig
      (mkIf config.services.barcodebuddy.enable or false localBbuddyConfig)
      (mkIf cfg.enable conf)
    ];
}
