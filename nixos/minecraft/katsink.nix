{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.minecraft-katsink-server;
in {
  services.minecraft-katsink-server = {
    enable = mkDefault true;
    argsFiles = [
      "user_jvm_args.txt"
      "/run/minecraft-katsink/unix_args.txt"
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
    services.minecraft-katsink-server = {
      # TODO: confinement.enable = true;
      gensokyo-zone.sharedMounts."minecraft/katsink/kat-kitchen-server" = {config, ...}: {
        root = config.rootDir + "/minecraft/katsink";
        path = mkDefault cfg.dataDir;
      };
      preStart = ''
        ${pkgs.coreutils}/bin/ln -sf $PWD/libraries/net/neoforged/neoforge/*/unix_args.txt $RUNTIME_DIRECTORY/unix_args.txt
      '';
    };
  };
  networking.firewall = mkIf cfg.enable {
    interfaces.local = {
      allowedTCPPorts = [cfg.port];
      allowedUDPPorts = mkIf cfg.serverProperties.enable-query or false [cfg.serverProperties."query.port"];
    };
  };
}
