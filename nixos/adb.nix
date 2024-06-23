{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.adb;
in {
  services.adb = {
    enable = mkDefault true;
    settings = {
      #a = mkDefault true;
    };
    devices = {
      bedroom-tv.serial = "10.1.1.67:5555";
    };
  };
  systemd.services = mkIf cfg.enable {
    adb = {
      environment.ADB_TRACE = mkDefault (toString ["adb"]);
    };
  };
  networking.firewall.interfaces.lan = mkIf (cfg.enable && cfg.settings.a or false == true) {
    allowedTCPPorts = [cfg.port];
  };
}
