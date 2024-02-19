{
  config,
  meta,
  lib,
  ...
}:
let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (config) networking;
  inherit (config.services) tailscale nginx;
  inherit (nginx) virtualHosts;
  cfg = config.services.kanidm;
  access = nginx.access.kanidm;
  proxyPass = mkDefault "https://${access.host}:${toString access.port}";
  locations = {
    "/" = {
      inherit proxyPass;
    };
    "=/ca.pem" = mkIf cfg.server.unencrypted.enable {
      alias = "${cfg.server.unencrypted.package.ca}";
    };
  };
  localLocations = vouchDomain: {
    "/".extraConfig = ''
      proxy_redirect $scheme://${nginx.access.vouch.domain or "login.${networking.domain}"}/ $scheme://${vouchDomain}/;
    '';
  };
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.access.ldap
  ];

  options.services.nginx.access.kanidm = with lib.types; {
    host = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "id.${networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "id.local.${networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "id.tail.${networking.domain}";
    };
    port = mkOption {
      type = port;
    };
    ldapHost = mkOption {
      type = str;
      default = access.host;
    };
    ldapPort = mkOption {
      type = port;
    };
    ldapEnable = mkOption {
      type = bool;
      default = false;
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = virtualHosts.${access.domain}.useACMEHost;
    };
  };
  config = {
    services.nginx = {
      access.kanidm = mkIf cfg.enableServer {
        domain = mkOptionDefault cfg.server.frontend.domain;
        host = mkOptionDefault "localhost";
        port = mkOptionDefault cfg.server.frontend.port;
        ldapPort = mkOptionDefault cfg.server.ldap.port;
        ldapEnable = mkDefault cfg.server.ldap.enable;
      };
      access.ldap = mkIf (cfg.enableServer && cfg.ldapEnable) {
        enable = mkDefault true;
        host = mkOptionDefault access.kanidm.ldapHost;
        port = mkOptionDefault access.kanidm.ldapPort;
        useACMEHost = mkDefault access.kanidm.useACMEHost;
      };
      virtualHosts = {
        ${access.domain} = {
          inherit locations;
        };
        ${access.localDomain} = {
          inherit (virtualHosts.${access.domain}) useACMEHost;
          addSSL = mkDefault (access.useACMEHost != null || virtualHosts.${access.domain}.forceSSL);
          local.enable = true;
          locations = mkMerge [
            locations
            (localLocations nginx.access.vouch.localDomain or "login.local.${networking.domain}")
          ];
        };
        ${access.tailDomain} = mkIf tailscale.enable {
          inherit (virtualHosts.${access.domain}) useACMEHost;
          addSSL = mkDefault (access.useACMEHost != null || virtualHosts.${access.domain}.forceSSL);
          local.enable = true;
          locations = mkMerge [
            locations
            (localLocations nginx.access.vouch.tailDomain or "login.tail.${networking.domain}")
          ];
        };
      };
    };

    services.kanidm.server.unencrypted.domain = mkMerge [
      [
        access.localDomain
        config.networking.fqdn
        config.networking.access.hostnameForNetwork.local
      ]
      (mkIf tailscale.enable [
        "id.tail.${config.networking.domain}"
        config.networking.access.hostnameForNetwork.tail
      ])
    ];

    networking.firewall = {
      interfaces.local.allowedTCPPorts = [
        389
      ];
      allowedTCPPorts = [
        636
      ];
    };
  };
}
