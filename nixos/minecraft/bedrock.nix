{config, lib, pkgs, ...}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.minecraft-bedrock-server;
in {
  services.minecraft-bedrock-server = {
    enable = mkDefault true;
    serverProperties = {
      server-name = "Kat's Server";
      online-mode = true;
      level-name = "KatBedrock";
    };
    packs = let
      addons = pkgs.minecraft-bedrock-addons;
    in {
      #tree-capitator-bp.package = addons.true-tree-capitator-bp;
      #tree-capitator-rp.package = addons.true-tree-capitator-rp;
      #tree-capitator-bh.package = addons.definitive-tree-capitator-bh;
      #tree-capitator-rs.package = addons.definitive-tree-capitator-rs;
    };
    allowPlayers = let
      base = 2535460000000000;
    in {
      Kyxna.xuid = base + 4308966797;
      arcnmx.xuid = base + 13399068799;
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
  networking.firewall.interfaces.local = let
    ports = [ cfg.serverProperties.server-port cfg.serverProperties.server-portv6 ];
  in mkIf cfg.enable {
    allowedUDPPorts = ports;
  };
}
