{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.minecraft-java-server;
  #forge = "neoforge";
  forge = "forge";
  backupsDir = "${config.kyuuto.dataDir}/minecraft/simplebackups/marka";
in {
  services.minecraft-java-server = {
    enable = mkDefault true;
    argsFiles = [
      "user_jvm_args.txt"
      "/run/minecraft-java/unix_args.txt"
    ];
    serverProperties = {
      enable-query = true;
      "query.port" = cfg.port;
    };
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
      gensokyo-zone.sharedMounts."minecraft/java/marka-server" = {config, ...}: {
        root = config.rootDir + "/minecraft/java";
        path = mkDefault cfg.dataDir;
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
      };
    };
    # TODO: tmpfiles.rules = ["d ${backupsDir} 775 ${cfg.user} admin - -"];
  };
  networking.firewall = mkIf cfg.enable {
    interfaces.local = {
      allowedTCPPorts = [cfg.port];
      allowedUDPPorts = mkIf cfg.serverProperties.enable-query or false [cfg.serverProperties."query.port"];
    };
  };
}
