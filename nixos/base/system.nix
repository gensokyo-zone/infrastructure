{
  config,
  gensokyo-zone,
  lib,
  pkgs,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf mkDefault;
in {
  hardware.enableRedistributableFirmware = mkDefault true;
  boot.zfs.package = mkDefault pkgs.zfs_unstable;
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    "net.ipv4.ip_forward" = mkDefault "1";
    "net.ipv6.conf.all.forwarding" = "1";
    "net.ipv4.conf.all.forwarding" = "1";
    "net.ipv6.conf.all.accept_ra_rt_info_max_plen" = 128;
    "net.ipv6.conf.default.accept_ra_rt_info_max_plen" = 128;
  };
  services.journald.extraConfig = "SystemMaxUse=512M";
  users.mutableUsers = mkDefault false;
  boot.tmp = {
    cleanOnBoot = mkAlmostOptionDefault true;
    useTmpfs = mkAlmostOptionDefault true;
    tmpfsSize = mkAlmostOptionDefault "80%";
  };
}
