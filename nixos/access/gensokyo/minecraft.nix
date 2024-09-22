{
  config,
  gensokyo-zone,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkMerge mkDefault;
  inherit (gensokyo-zone.lib) domain;
  inherit (config.services) nginx;
  minecraftBackups = "${config.kyuuto.dataDir}/minecraft/simplebackups";
  minecraftDownloads = "${config.kyuuto.shareDir}/projects/minecraft/public";
  root = pkgs.linkFarm "genso-minecraft-backups" [
    {
      name = "minecraft/downloads";
      path = minecraftDownloads;
    }
    {
      name = "minecraft/backups";
      path = minecraftBackups;
    }
    {
      name = "minecraft/wiki/dummy";
      path = "nope";
    }
  ];
  extraConfig = ''
    gzip off;
    autoindex on;
  '';
  authPrivate = ''
    auth_basic "private";
    auth_basic_user_file ${config.sops.secrets.access-web-htpasswd.path};
  '';
in {
  services.nginx.virtualHosts.gensokyoZone = {
    locations = {
      "/minecraft" = {
        inherit root extraConfig;
      };
      "/minecraft/wiki" = {
        return = "302 https://wiki.${domain}/minecraft/";
      };
      "/minecraft/backups" = {
        inherit root;
        extraConfig = mkMerge [
          extraConfig
          authPrivate
        ];
      };
    };
  };
  systemd.services.nginx.serviceConfig.BindReadOnlyPaths = [
    minecraftBackups
    minecraftDownloads
  ];
  sops.secrets.access-web-htpasswd = {
    sopsFile = mkDefault ../../secrets/access.yaml;
    owner = nginx.user;
  };
}
