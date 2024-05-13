{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  cfg = config.services.nginx;
in {
  networking.firewall.allowedTCPPorts = mkIf cfg.enable [
    443
    80
  ];
}
