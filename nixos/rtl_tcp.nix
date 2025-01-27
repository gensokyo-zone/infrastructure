{
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  cfg = config.services.rtl_tcp;
in {
  services.rtl_tcp = {
    enable = mkAlmostOptionDefault true;
  };
  hardware.rtl-sdr.enable = mkAlmostOptionDefault true;
  networking.firewall.interfaces.lan = mkIf (cfg.enable && !cfg.openFirewall) {
    allowedTCPPorts = [cfg.port];
  };
}
