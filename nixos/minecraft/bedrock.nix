{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.minecraft-bedrock-server;
in {
  services.minecraft-bedrock-server = {
    enable = mkDefault true;
    serverProperties = {
      server-name = "Kat's Server";
      online-mode = true;
      allow-cheats = true;
      #level-name = "KatBedrock";
      level-name = "KatBedrockBeta";
      default-player-permission-level = "visitor";
    };
    packs = let
      addons = pkgs.minecraft-bedrock-addons;
    in {
      tree-capitator-bp.package = addons.true-tree-capitator-bp;
      tree-capitator-rp.package = addons.true-tree-capitator-rp;
      #tree-capitator-bh.package = addons.definitive-tree-capitator-bh;
      #tree-capitator-rs.package = addons.definitive-tree-capitator-rs;
    };
    allowPlayers = let
      base = 2535420000000000;
      nums = 1760;
    in {
      Kyxna = {
        xuid = base + 44308966797;
        permission = "operator";
      };
      arcnmx = {
        xuid = base + 53399068799;
        permission = "operator";
      };
      "ConnieHeart${toString (base / 1000000000000 + nums)}".xuid = base + 417602225;
    };
  };
  systemd.services.minecraft-bedrock-server = mkIf cfg.enable {
    confinement.enable = true;
    gensokyo-zone.sharedMounts."minecraft/bedrock" = {config, ...}: {
      root = config.rootDir + "/${config.subpath}";
      path = mkDefault cfg.dataDir;
    };
  };
  users = mkIf cfg.enable {
    users.${cfg.user}.uid = 913;
    groups.${cfg.group}.gid = config.users.users.${cfg.user}.uid;
  };
  networking.firewall.interfaces = let
    ports = [cfg.serverProperties.server-port cfg.serverProperties.server-portv6];
  in
    mkIf cfg.enable {
      local.allowedUDPPorts = ports;
      peeps.allowedUDPPorts = ports;
    };
}
