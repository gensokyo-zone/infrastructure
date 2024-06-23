let
  deviceModule = {
    config,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption mkEnableOption;
  in {
    options = with lib.types; {
      enable =
        mkEnableOption "adb device"
        // {
          default = true;
        };
      uphold = mkOption {
        type = bool;
        default = true;
      };
      serial = mkOption {
        type = str;
      };
    };
  };
in
  {
    config,
    gensokyo-zone,
    utils,
    pkgs,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption mkPackageOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
    inherit (lib.attrsets) filterAttrs mapAttrsToList;
    inherit (lib.cli) toGNUCommandLine;
    inherit (utils) escapeSystemdExecArgs escapeSystemdPath;
    inherit (gensokyo-zone.lib) mapOptionDefaults;
    cfg = config.services.adb;
    enabledDevices = filterAttrs (_: device: device.enable) cfg.devices;
  in {
    options.services.adb = with lib.types; {
      enable = mkEnableOption "adb server";
      package = mkPackageOption pkgs "android-tools" {};
      rulesPackage = mkPackageOption pkgs "android-udev-rules" {};
      user = mkOption {
        type = str;
        default = "adb";
      };
      port = mkOption {
        type = port;
        default = 5037;
      };
      extraArguments = mkOption {
        type = listOf str;
        default = [];
      };
      settings = mkOption {
        type = attrsOf (oneOf [str int (nullOr bool)]);
      };
      devices = mkOption {
        type = attrsOf (submoduleWith {
          modules = [deviceModule];
          specialArgs = {
            inherit gensokyo-zone;
            nixosConfig = config;
          };
        });
        default = {};
      };
    };
    config = let
      confService.services.adb = {
        settings = mapOptionDefaults {
          H = config.networking.hostName;
          P = cfg.port;
        };
      };
      conf.services.udev.packages = [cfg.rulesPackage];
      conf.environment.systemPackages = [cfg.package];
      conf.users.groups.adbusers = {};
      conf.systemd.services.adb = {
        upholds = let
          upheldDevices = filterAttrs (_: device: device.uphold) enabledDevices;
        in
          mapAttrsToList (_: device: "adb-device@${escapeSystemdPath device.serial}.service") upheldDevices;
        after = ["network.target"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = mkOptionDefault "forking";
          ExecStart = let
            args = toGNUCommandLine {} cfg.settings ++ cfg.extraArguments;
          in [
            "${cfg.package}/bin/adb start-server ${escapeSystemdExecArgs args}"
          ];
          ExecStop = [
            "${cfg.package}/bin/adb kill-server"
          ];
          WorkingDirectory = "/var/lib/adb";
          StateDirectory = "adb";
          RuntimeDirectory = "adb";
          User = cfg.user;
        };
      };
      conf.systemd.services."adb-device@" = rec {
        requisite = ["adb.service"];
        partOf = requisite;
        after = requisite;
        environment = mapOptionDefaults {
          ANDROID_SERIAL = "%I";
        };
        path = [cfg.package pkgs.coreutils];
        serviceConfig = mapOptionDefaults {
          User = cfg.user;
        };
        script = ''
          set -eu

          while true; do
            sleep 1
            DEVICE_ONLINE=
            if ADB_STATE=$(adb get-state 2>/dev/null); then
              if [[ $ADB_STATE == device ]]; then
                DEVICE_ONLINE=1
              fi
            fi
            if [[ -n $DEVICE_ONLINE ]] || timeout 5 adb connect $ANDROID_SERIAL; then
              sleep 10
            else
              sleep 4
            fi
          done
        '';
      };
      conf.users.users.adb = mkIf (cfg.user == "adb") {
        isSystemUser = true;
        group = mkDefault "adbusers";
        home = mkDefault "/var/lib/adb";
      };
    in
      mkMerge [
        confService
        (mkIf cfg.enable conf)
      ];
  }
