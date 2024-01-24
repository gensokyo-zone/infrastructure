{
  config,
  lib,
}: let
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.tautulli;
  access = config.services.nginx.access.tautulli;
  proxyPass = mkDefault "https://${access.host}:${toString access.port}";
  locations = {
    "/" = {
      inherit proxyPass;
    };
  };
in {
  options.services.nginx.access.tautulli = with lib.types; {
    host = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "tautulli.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
    };
  };
  config.services.nginx = {
    access.tautulli = mkIf cfg.enable {
      host = mkOptionDefault "localhost";
      port = mkOptionDefault cfg.port;
    };
    virtualHosts = {
      ${access.domain} = {
        inherit locations;
      };
    };
  };
}
