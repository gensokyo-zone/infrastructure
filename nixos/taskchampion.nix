{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.taskchampion-sync-server;
in {
  services.taskchampion-sync-server = {
    enable = mkDefault true;
  };
  users = mkIf (cfg.enable && cfg.user == "taskchampion") {
    users.taskchampion.uid = 917;
    groups.taskchampion.gid = config.users.users.taskchampion.uid;
  };
  systemd.services.taskchampion-sync-server = mkIf cfg.enable {
    confinement.enable = true;
    gensokyo-zone.sharedMounts.taskchampion.path = mkDefault cfg.dataDir;
  };
  networking.firewall.interfaces.lan = mkIf cfg.enable {
    allowedTCPPorts = [cfg.port];
  };
}
