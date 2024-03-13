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
      enable =
        mkEnableOption "global access"
        // {
          default = access.useACMEHost != null;
        };
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
    domain = mkOption {
      type = str;
      default = "unifi.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "unifi.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "unifi.tail.${config.networking.domain}";
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = null;
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
      locations = {
        "/" = {
          proxyPass = access.url;
        };
      };
    in {
      "${access.domain}@management" = mkIf access.global.management {
        listen =
          map (addr: {
            inherit addr;
            port = access.managementPort;
            ssl = true;
          })
          nginx.defaultListenAddresses;
        serverName = access.domain;
        default = mkDefault true;
        forceSSL = mkDefault true;
        kTLS = mkDefault true;
        useACMEHost = mkDefault access.useACMEHost;
        inherit locations extraConfig;
      };
      ${access.domain} = {
        vouch.enable = mkDefault true;
        local.enable = mkDefault (!access.global.enable);
        forceSSL = mkDefault access.global.enable;
        addSSL = mkDefault (!access.global.enable && access.useACMEHost != null);
        kTLS = mkDefault true;
        useACMEHost = mkDefault access.useACMEHost;
        inherit locations extraConfig;
      };
      ${access.localDomain} = {
        serverAliases = mkIf tailscale.enable [access.tailDomain];
        useACMEHost = mkDefault access.useACMEHost;
        addSSL = mkDefault (access.useACMEHost != null);
        kTLS = mkDefault true;
        local.enable = true;
        inherit locations extraConfig;
      };
    };
  };
  config.networking.firewall = {
    interfaces.local.allowedTCPPorts = [access.managementPort];
    allowedTCPPorts = mkIf access.global.management [access.managementPort];
  };
}
