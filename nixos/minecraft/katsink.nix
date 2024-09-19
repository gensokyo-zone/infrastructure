{
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
      "libraries/net/neoforged/neoforge/21.1.54/unix_args.txt"
    ];
  };
  users = mkIf cfg.enable {
    users.${cfg.user}.uid = 913;
    groups.${cfg.group}.gid = config.users.users.${cfg.user}.uid;
  };

  systemd = mkIf cfg.enable {
    services.minecraft-katsink-server = {
      # TODO: confinement.enable = true;
      gensokyo-zone.sharedMounts."minecraft/katsink/kat-kitchen-server" = {config, ...}: {
        root = config.rootDir + "/minecraft/katsink";
        path = mkDefault cfg.dataDir;
      };
      # TODO: serviceConfig.ExecStart = mkForce [ "${pkgs.runtimeShell} ${cfg.dataDir}/run.sh" ]; for imperative updates ?
    };
    sockets.minecraft-katsink-server = {
      socketConfig.SocketGroup = "admin";
    };
  };
  networking.firewall = mkIf cfg.enable {
    interfaces.local.allowedTCPPorts = [cfg.port];
  };
}
