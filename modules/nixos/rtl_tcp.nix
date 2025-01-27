{
  pkgs,
  config,
  lib,
  utils,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption mkPackageOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault mkDefault;
  inherit (lib.trivial) mapNullable;
  inherit (lib.lists) optionals;
  inherit (utils) escapeSystemdExecArgs;
  cfg = config.services.rtl_tcp;
  defaultPort = 1234;
  defaultUser = "rtl_tcp";
in {
  options.services.rtl_tcp = with lib.types; {
    enable = mkEnableOption "rtl_tcp";
    package = mkPackageOption pkgs "rtl-sdr-blog" {};
    port = mkOption {
      type = port;
      default = defaultPort;
    };
    openFirewall = mkOption {
      type = bool;
      default = false;
    };
    user = mkOption {
      type = nullOr str;
      default = defaultUser;
    };
    group = mkOption {
      type = nullOr str;
    };
    extraArgs = mkOption {
      type = listOf str;
      default = [];
    };
  };

  config = let
    serviceConf.services.rtl_tcp = {
      group = mkOptionDefault (if cfg.user == defaultUser then defaultUser else null);
    };
    execArgs = optionals (cfg.port != defaultPort) [
      "-p" (toString cfg.port)
    ] ++ cfg.extraArgs;
    conf.systemd.services.rtl_tcp = {
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/rtl_tcp ${escapeSystemdExecArgs execArgs}";
        DynamicUser = mkDefault (cfg.user == null);
        User = if cfg.user != null then cfg.user else defaultUser;
        Group = cfg.group;
      };
    };
    conf.environment.systemPackages = [cfg.package];
    conf.users.users.${defaultUser} = mkIf (cfg.user == defaultUser) {
      group = cfg.group;
      isSystemUser = true;
      extraGroups = mkIf config.hardware.rtl-sdr.enable [
        "plugdev"
      ];
    };
    conf.users.groups.${defaultUser} = mkIf (cfg.user == defaultUser) {
    };
    conf.networking.firewall = {
      allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
    };
  in mkMerge [
    (mkIf cfg.enable conf)
    serviceConf
  ];
}
