{config, lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf;
  cfg = config.proxmox.node;
in {
  options.proxmox.node = with lib.types; {
    enable = mkEnableOption "Proxmox Node";
  };
  config.proxmox.node = {
    name = mkIf cfg.enable (mkAlmostOptionDefault config.access.hostName);
  };
}
