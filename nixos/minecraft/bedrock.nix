{config, lib, ...}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.minecraft-bedrock-server;
in {
  services.minecraft-bedrock-server = {
    enable = mkDefault true;
    serverProperties = {
      server-name = "Kat's Server";
      gamemode = "survival";
      difficulty = "easy";
      allow-cheats = false;
      max-players = 10;
      online-mode = true;
      white-list = false;
      server-port = 19132;
      server-portv6 = 19133;
      view-distance = 32;
      tick-distance = 4;
      player-idle-timeout = 30;
      max-threads = 8;
      level-name = "Bedrock level";
      level-seed = "";
      default-player-permission-level = "member";
      texturepack-required = false;
      content-log-file-enabled = false;
      compression-threshold = 1;
      server-authoritative-movement = "server-auth";
      player-movement-score-threshold = 20;
      player-movement-distance-threshold = 0.3;
      player-movement-duration-threshold-in-ms = 500;
      correct-player-movement = false;
    };
  };
  users = mkIf cfg.enable {
    users.${cfg.user}.uid = 913;
    groups.${cfg.group}.gid = config.users.users.${cfg.user}.uid;
  };
  networking.firewall.interfaces.local = let
    ports = [ cfg.serverProperties.server-port cfg.serverProperties.server-portv6 ];
  in mkIf cfg.enable {
    allowedUDPPorts = ports;
  };
}
