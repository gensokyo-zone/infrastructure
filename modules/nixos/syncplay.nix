{
  pkgs,
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf;
  cfg = config.services.syncplay;
in {
  options.services.syncplay = with lib.types; {
    openFirewall = mkOption {
      type = bool;
      default = false;
    };
  };

  config.networking.firewall = mkIf cfg.enable {
    allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
  };

  config.systemd.services.syncplay = mkIf cfg.enable {
    wants = mkIf (cfg.useACMEHost != null) ["acme-finished-${cfg.useACMEHost}.target"];
    after = mkIf (cfg.useACMEHost != null) ["acme-selfsigned-${cfg.useACMEHost}.service"];
    confinement = {
      enable = mkAlmostOptionDefault true;
      packages = config.systemd.services.syncplay.path;
    };
    path = mkIf (cfg.passwordFile != null || cfg.saltFile != null) [pkgs.coreutils];
    serviceConfig = {
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateMounts = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectControlGroups = true;
      ProtectProc = "invisible";
      RemoveIPC = true;
    };
  };
}
