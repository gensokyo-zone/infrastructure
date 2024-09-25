{
  pkgs,
  config,
  systemConfig,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapDefaults;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib) versions;
  inherit (systemConfig.exports.services) minecraft;
  cfg = config.services.minecraft-java-server;
  #forge = "neoforge";
  forge = "forge";
  mcVersion = "1.20.1";
  backupsDir = "${config.kyuuto.dataDir}/minecraft/simplebackups/marka";
  enableDynmap = minecraft.ports.dynmap.enable;
  enableBluemap = minecraft.ports.bluemap.enable;
in {
  services.minecraft-java-server = {
    enable = mkDefault true;
    argsFiles = [
      "user_jvm_args.txt"
      "/run/minecraft-java/unix_args.txt"
    ];
    serverProperties = let
      props = {
        enable-query = true;
        "query.port" = cfg.port;
        pvp = false;
        broadcast-console-to-ops = false;
        op-permission-level = 2;
      };
    in mkMerge [
      (mapDefaults props)
      (mkIf enableDynmap {
        max-tick-time = 60000 * 12;
      })
    ];
    allowPlayers = {
      katrynn = {
        uuid = "356d8cf2-246a-4c07-b547-422aea06c0ab";
        permissionLevel = 4;
      };
      arcnmx = {
        uuid = "e9244315-848c-424a-b004-ae5305449fee";
        permissionLevel = 4;
      };
      Matricariac = {
        uuid = "e6204250-05dc-4f4a-890a-71619170a321";
        permissionLevel = 2;
      };
      Kaosubaloo = {
        uuid = "1340bc67-5296-4f6d-9643-29011971f88e";
        permissionLevel = 1; # 2?
      };
    };
  };
  users = mkIf cfg.enable {
    users.${cfg.user}.uid = 913;
    groups.${cfg.group} = {
      gid = config.users.users.${cfg.user}.uid;
      inherit (config.users.groups.admin) members;
    };
  };

  systemd = mkIf cfg.enable {
    services.minecraft-java-server = {
      # TODO: confinement.enable = true;
      gensokyo-zone = {
        sharedMounts."minecraft/java/marka-server" = {config, ...}: {
          root = config.rootDir + "/minecraft/java";
          path = mkDefault cfg.dataDir;
        };
        cacheMounts = {
          "minecraft/dynmap" = mkIf enableDynmap {
            path = mkDefault "${cfg.dataDir}/dynmap";
          };
          "minecraft/bluemap" = mkIf enableBluemap {
            path = mkDefault "${cfg.dataDir}/bluemap";
          };
        };
      };
      preStart = let
        forgeDir = {
          neoforge = "neoforged/neoforge";
          forge = "minecraftforge/forge";
        }.${forge};
      in ''
        ${pkgs.coreutils}/bin/ln -sf $PWD/libraries/net/${forgeDir}/*/unix_args.txt $RUNTIME_DIRECTORY/unix_args.txt
      '';
      serviceConfig = {
        BindPaths = [
          "${backupsDir}:${cfg.dataDir}/simplebackups"
        ];
        BindReadOnlyPaths = let
          dynmap = assert forge == "forge"; pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/fRQREgAc/versions/RtI5TFAi/Dynmap-3.7-beta-6-${forge}-${versions.majorMinor mcVersion}.jar";
            sha256 = "sha256-rrs7ab0OKEwkPBYGm4CDD/I5341P/f4wwU52hyKd/Ls=";
          };
          dynmap-block-scan = assert forge == "forge"; pkgs.fetchurl {
            url = "https://dynmap.us/builds/DynmapBlockScan/DynmapBlockScan-3.6-${forge}-${versions.majorMinor mcVersion}.jar";
            sha256 = "sha256-YOuXeE+6kOtFpA42Yhv5sBdjpvZsuHXvx5fnocY5yvM=";
          };
          bluemap = assert forge == "forge"; pkgs.fetchurl {
            url = "https://github.com/BlueMap-Minecraft/BlueMap/releases/download/v5.3/BlueMap-5.3-${forge}-${versions.majorMinor mcVersion}.jar";
            sha256 = "sha256-eN4wWUItI7WleFk1KUSTM5EQv9ri4QRKrBuvCgN89qU=";
          };
        in mkMerge [
          (mkIf enableDynmap [
            "${dynmap}:${cfg.dataDir}/mods/${dynmap.name}"
            "${dynmap-block-scan}:${cfg.dataDir}/mods/${dynmap-block-scan.name}"
          ])
          (mkIf enableBluemap [
            "${bluemap}:${cfg.dataDir}/mods/${bluemap.name}"
          ])
        ];
        LogFilterPatterns = [
          "~.*Invalid modellist patch"
          "~.*Invalid modellist patch.*"
        ];
      };
    };
    tmpfiles.rules = let
      inherit (config.systemd.services.minecraft-java-server.gensokyo-zone) cacheMounts;
    in mkMerge [
      #["d ${backupsDir} 775 ${cfg.user} ${cfg.group} - -"]
      (mkIf enableDynmap ["d ${cacheMounts."minecraft/dynmap".source} 750 ${cfg.user} ${cfg.group} - -"])
      (mkIf enableBluemap ["d ${cacheMounts."minecraft/bluemap".source} 750 ${cfg.user} ${cfg.group} - -"])
    ];
  };
  networking.firewall = mkIf cfg.enable {
    interfaces.local = {
      allowedTCPPorts = [cfg.port];
      allowedUDPPorts = mkIf cfg.serverProperties.enable-query or false [cfg.serverProperties."query.port"];
    };
    interfaces.lan = {
      allowedTCPPorts = [
        (mkIf enableDynmap minecraft.ports.dynmap.port)
        (mkIf enableBluemap minecraft.ports.bluemap.port)
      ];
    };
  };
}
