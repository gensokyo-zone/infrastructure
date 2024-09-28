{config, systemConfig, lib, ...}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.attrsets) mapAttrs' mapAttrsToList nameValuePair;
  inherit (lib.lists) concatMap;
  inherit (lib.strings) replaceStrings;
  inherit (config.sops.secrets) restic-shared-repo-b2 restic-shared-password restic-shared-env-b2;
  group = "backups";
  # TODO: this properly as a module or something
  sharedServices = {
    hass.config = config.services.home-assistant;
    grocy.config = config.services.grocy;
    barcodebuddy.config = config.services.barcodebuddy;
    kanidm = {
      config = config.services.kanidm;
      enable = config.services.kanidm.enableServer;
    };
    mosquitto.config = config.services.mosquitto;
    plex = {
      config = config.services.plex;
      compression = "auto";
    };
    postgresql = {
      # TODO: synchronize with postgresqlBackup service via flock or After=
      config = config.services.postgresql;
      subpath = "postgresql/dump";
    };
    taskchampion.config = config.services.taskchampion-sync-server;
    unifi = {
      config = config.services.unifi;
      subpath = "unifi/data/backup";
    };
    zigbee2mqtt.config = config.services.zigbee2mqtt;
    vaultwarden.config = config.services.vaultwarden;
    "minecraft/bedrock".config = config.services.minecraft-bedrock-server;
    minecraft-java = {
      config = config.services.minecraft-java-server;
      subpath = "minecraft/java/marka-server";
    };
  };
in {
  services.restic.backups = let
    isBackup = config.networking.hostName == "hakurei";
    mkSharedPath = subpath: "/mnt/shared/${subpath}";
    mkBackupB2 = name: subpath': { config, enable ? config.enable, user ? config.user or null, subpath ? subpath', path ? mkSharedPath subpath, compression ? "max" }: let
      tags = [
        "infra"
        "shared-${name}"
        "system-${systemConfig.name}"
      ];
    in mkIf (enable || isBackup) {
      user = mkIf (enable && user != null) user;
      repositoryFile = restic-shared-repo-b2.path;
      passwordFile = restic-shared-password.path;
      environmentFile = restic-shared-env-b2.path;
      paths = [path];
      extraBackupArgs = mkMerge [
        (mkIf (compression != "auto") [
          "--compression" compression
        ])
        (concatMap (tag: ["--tag" tag]) tags)
      ];
      timerConfig = {
        OnCalendar = "03:30";
        Persistent = true;
        RandomizedDelaySec = "4h";
      };
    };
    backups = mapAttrs' (subpath: service: let
      name = replaceStrings [ "/" ] [ "-" ] subpath;
    in nameValuePair "${name}-b2" (mkBackupB2 name subpath service)) sharedServices;
  in backups;
  users.groups.${group} = {
    members = mapAttrsToList (_: { config, enable ? config.enable, user ? config.user or null, ... }: mkIf (enable && user != null) user) sharedServices;
  };
  sops.secrets = let
    sopsFile = mkDefault ../secrets/restic.yaml;
    mode = "0640";
  in {
    restic-shared-env-b2 = {
      inherit group mode;
    };
    restic-shared-password = {
      inherit sopsFile group mode;
    };
    restic-shared-repo-b2 = {
      inherit sopsFile group mode;
    };
  };
}
