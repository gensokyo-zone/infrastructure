{ config, utils, lib, ... }: let
  inherit (lib) mkAfter;
  cfg = config.services.deluge;
  shadowDir = "/mnt/shadow";
  mediaDir = "${shadowDir}/deluge";
in {
  services.deluge = {
    config = {
      download_location = "${mediaDir}/download";
      move_completed_path = "${mediaDir}/complete";
      move_completed = true;
    };
  };
  systemd.services = {
    deluged = {
      bindsTo = [
        "${utils.escapeSystemdPath shadowDir}.mount"
      ];
      unitConfig = {
        RequiresMountsFor = [
          shadowDir
        ];
      };
    };
  };
  systemd.tmpfiles.rules = mkAfter [
    # work around https://github.com/NixOS/nixpkgs/blob/8f40f2f90b9c9032d1b824442cfbbe0dbabd0dbd/nixos/modules/services/torrent/deluge.nix#L205-L210
    # (this is dumb, there's no guarantee the disk is even mounted)
    "z '${cfg.config.move_completed_path}' 0775 ${cfg.user} ${cfg.group}"
    "x '${mediaDir}/*'"
  ];
}
