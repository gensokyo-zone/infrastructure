{
  config,
  lib,
}: let
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.radarr;
  access = config.services.nginx.access.radarr;
  proxyPass = mkDefault "https://${access.host}:${toString access.port}";
  locations = {
    "/" = {
      inherit proxyPass;
    };
  };
in {
  options.services.nginx.access.radarr = with lib.types; {
    host = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "radarr.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
      default = cfg.port;
    };
  };
  config.services.nginx = {
    access.radarr = mkIf cfg.enable {
      host = mkOptionDefault "localhost";
    };
    virtualHosts = {
      ${access.domain} = {
        inherit locations;
      };
    };
  };
}
