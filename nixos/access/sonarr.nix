{
  config,
  lib,
}: let
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.sonarr;
  access = config.services.nginx.access.sonarr;
  proxyPass = mkDefault "https://${access.host}:${toString access.port}";
  locations = {
    "/" = {
      inherit proxyPass;
    };
  };
in {
  options.services.nginx.access.sonarr = with lib.types; {
    host = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "sonarr.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
      default = cfg.port;
    };
  };
  config.services.nginx = {
    access.sonarr = mkIf cfg.enable {
      host = mkOptionDefault "localhost";
    };
    virtualHosts = {
      ${access.domain} = {
        inherit locations;
      };
    };
  };
}
