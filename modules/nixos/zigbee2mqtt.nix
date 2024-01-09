{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption;
  cfg = config.services.zigbee2mqtt;
in {
  options.services.zigbee2mqtt = with lib.types; {
    openFirewall = mkEnableOption "firewall port";
    domain = mkOption {
      type = str;
      default = config.networking.domain;
    };
  };

  config = {
    networking.firewall.allowedTCPPorts = mkIf (cfg.enable && cfg.openFirewall) [
      cfg.settings.frontend.port
    ];
  };
}
