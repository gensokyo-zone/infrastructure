{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  inherit (config.services) nginx tailscale unifi;
  access = nginx.access.unifi;
in {
  options.services.nginx.access.unifi = with lib.types; {
    global = {
      management = mkEnableOption "global management port access";
    };
    host = mkOption {
      type = str;
    };
    url = mkOption {
      type = str;
      default = "https://${access.host}:${toString access.managementPort}";
    };
    managementPort = mkOption {
      type = port;
      default = 8443;
    };
  };
  config.services.nginx = {
    access.unifi = mkIf unifi.enable {
      host = mkOptionDefault "localhost";
    };
    virtualHosts = let
      extraConfig = ''
        proxy_redirect off;
        proxy_buffering off;
      '';
      locations."/" = {
        proxyPass = mkDefault access.url;
      };
      name.shortServer = mkDefault "unifi";
      kTLS = mkDefault true;
    in {
      unifi'management = mkIf access.global.management {
        listen'.management = {
          port = access.managementPort;
          ssl = true;
          extraParameters = [ "default_server" ];
        };
        ssl = {
          force = true;
          cert.copyFromVhost = "unifi";
        };
        inherit name locations extraConfig kTLS;
      };
      unifi = {
        inherit name locations extraConfig kTLS;
        vouch.enable = mkDefault true;
        ssl.force = mkDefault true;
      };
      unifi'local = {
        inherit name locations extraConfig kTLS;
        ssl.cert.copyFromVhost = "unifi";
        local.enable = true;
      };
    };
  };
  config.networking.firewall = {
    interfaces.local.allowedTCPPorts = [access.managementPort];
    allowedTCPPorts = mkIf access.global.management [access.managementPort];
  };
}
