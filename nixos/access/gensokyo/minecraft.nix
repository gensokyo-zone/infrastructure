{
  config,
  gensokyo-zone,
  access,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (gensokyo-zone.lib) domain;
  inherit (config.services) nginx;
  minecraftSystem = access.systemForService "minecraft";
  inherit (minecraftSystem.exports.services) minecraft;
  minecraftBackups = "${config.kyuuto.dataDir}/minecraft/simplebackups";
  minecraftDownloads = "${config.kyuuto.shareDir}/projects/minecraft/public";
  upstreamNameDynmap = "minecraft'dynmap";
  upstreamNameBluemap = "minecraft'bluemap";
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
      name = "minecraft/wiki/empty";
      path = "nope";
    }
    {
      name = "minecraft/dmap/empty";
      path = "nope";
    }
    {
      name = "minecraft/bmap/empty";
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
  services.nginx = {
    upstreams' = {
      ${upstreamNameDynmap} = mkIf minecraft.ports.dynmap.enable {
        servers.service.accessService = {
          name = "minecraft";
          system = minecraftSystem.name;
          port = "dynmap";
        };
      };
      ${upstreamNameBluemap} = mkIf minecraft.ports.bluemap.enable {
        servers.service.accessService = {
          name = "minecraft";
          system = minecraftSystem.name;
          port = "bluemap";
        };
      };
    };
    virtualHosts.gensokyoZone = {
      locations = {
        "/minecraft" = {
          inherit root extraConfig;
        };
        "/minecraft/wiki" = {
          return = "302 https://wiki.${domain}/minecraft/";
        };
        "/minecraft/map" = {xvars, ...}: let
          defaultMap =
            if minecraft.ports.bluemap.enable
            then "bmap"
            else "dmap";
        in {
          return = "302 ${xvars.get.scheme}://${xvars.get.host}/minecraft/${defaultMap}/";
        };
        "/minecraft/dmap/" = mkIf minecraft.ports.dynmap.enable {
          proxy = {
            enable = true;
            upstream = mkDefault upstreamNameDynmap;
            path = "/";
          };
          extraConfig = mkMerge [
            "gzip off;"
            authPrivate
          ];
        };
        "/minecraft/bmap/" = mkIf minecraft.ports.bluemap.enable {
          proxy = {
            enable = true;
            upstream = mkDefault upstreamNameBluemap;
            path = "/";
          };
          extraConfig = mkMerge [
            "gzip off;"
            authPrivate
          ];
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
