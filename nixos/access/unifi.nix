{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.lists) concatMap;
  inherit (config.services) nginx tailscale unifi;
  access = nginx.access.unifi;
in {
  options.services.nginx.access.unifi = with lib.types; {
    global.enable = mkEnableOption "global access" // {
      default = access.useACMEHost != null;
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
      streamListen = { config, ... }: {
        listen = concatMap (addr: [
          {
            inherit addr;
            port = 80;
            ssl = false;
          }
          (mkIf (config.addSSL || config.forceSSL) {
            inherit addr;
            port = 443;
            ssl = true;
          })
          (mkIf (config.addSSL || config.forceSSL) {
            inherit addr;
            port = access.managementPort;
            ssl = true;
          })
        ]) nginx.defaultListenAddresses;
      };
    in {
      ${access.domain} = mkIf access.global.enable (mkMerge [ {
        vouch.enable = true;
        forceSSL = mkDefault true;
        kTLS = mkDefault true;
        useACMEHost = mkDefault access.useACMEHost;
        inherit locations extraConfig;
      } streamListen ]);
      ${access.localDomain} = mkMerge [ {
        serverAliases = mkIf tailscale.enable [ access.tailDomain ];
        useACMEHost = mkDefault access.useACMEHost;
        addSSL = mkDefault (access.useACMEHost != null);
        kTLS = mkDefault true;
        local.enable = true;
        inherit locations extraConfig;
      } streamListen ];
    };
  };
  config.networking.firewall = {
    interfaces.local.allowedTCPPorts = [ access.managementPort ];
    allowedTCPPorts = mkIf access.global.enable [ access.managementPort ];
  };
}
