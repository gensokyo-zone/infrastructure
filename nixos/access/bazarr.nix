{
  config,
  lib,
}: let
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.bazarr;
  access = config.services.nginx.access.bazarr;
  proxyPass = mkDefault "https://${access.host}:${toString access.port}";
  locations = {
    "/" = {
      inherit proxyPass;
    };
  };
in {
  options.services.nginx.access.bazarr = with lib.types; {
    host = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "bazarr.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
    };
  };
  config.services.nginx = {
    access.bazarr = mkIf cfg.enable {
      host = mkOptionDefault "localhost";
      port = mkOptionDefault cfg.listenPort;
    };
    virtualHosts = {
      ${access.domain} = {
        inherit locations;
      };
    };
  };
}
