{
  config,
  lib,
}: let
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.ombi;
  access = config.services.nginx.access.ombi;
  proxyPass = mkDefault "https://${access.host}:${toString access.port}";
  locations = {
    "/" = {
      inherit proxyPass;
    };
  };
in {
  options.services.nginx.access.ombi = with lib.types; {
    host = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "ombi.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
    };
  };
  config.services.nginx = {
    access.ombi = mkIf cfg.enable {
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
