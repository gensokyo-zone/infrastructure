{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) home-assistant tailscale;
  proxyPass = "http://localhost:${toString home-assistant.config.http.server_port}/";
in {
  services.nginx.virtualHosts."home.local.${config.networking.domain}" = mkIf home-assistant.enable {
    local.enable = mkDefault true;
    locations."/" = {
      inherit proxyPass;
    };
  };
  services.nginx.virtualHosts."home.tail.${config.networking.domain}" = mkIf (home-assistant.enable && tailscale.enable) {
    local.enable = mkDefault true;
    locations."/" = {
      inherit proxyPass;
    };
  };
}
