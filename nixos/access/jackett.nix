{
  config,
  lib,
}: let
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.jackett;
  access = config.services.nginx.access.jackett;
  proxyPass = mkDefault "https://${access.host}:${toString access.port}";
  locations = {
    "/" = {
      inherit proxyPass;
    };
  };
in {
  options.services.nginx.access.jackett = with lib.types; {
    host = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "jackett.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
      default = cfg.port;
    };
  };
  config.services.nginx = {
    access.jackett = mkIf cfg.enable {
      host = mkOptionDefault "localhost";
    };
    virtualHosts = {
      ${access.domain} = {
        inherit locations;
      };
    };
  };
}
