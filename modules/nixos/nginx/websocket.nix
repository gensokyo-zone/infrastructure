{lib, ...}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption mkEnableOption;
  wsModule = {config, ...}: {
    options = with lib.types; {
      proxy.websocket.enable = mkEnableOption "websocket proxy";
    };
    config = mkIf config.proxy.websocket.enable {
      extraConfig = ''
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };
  };
  hostModule = {config, ...}: {
    imports = [wsModule];

    options = with lib.types; {
      locations = mkOption {
        type = attrsOf (submodule wsModule);
      };
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submodule hostModule);
    };
  };
}
