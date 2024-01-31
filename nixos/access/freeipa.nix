{
  config,
  meta,
  lib,
  ...
}:
let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) tailscale;
  inherit (config.services.nginx) virtualHosts;
  access = config.services.nginx.access.freeipa;
  inherit (config.services.nginx.access) ldap;
  locations = {
    "/" = {
      proxyPass = mkDefault access.proxyPass;
      recommendedProxySettings = false;
      extraConfig = ''
        proxy_set_header Host ${access.domain};
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
        proxy_redirect https://${access.domain}/ $scheme://$host/;
      '';
    };
  };
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.access.ldap
  ];

  options.services.nginx.access.freeipa = with lib.types; {
    host = mkOption {
      type = str;
    };
    proxyPass = mkOption {
      type = str;
      default = let
        scheme = if access.port == 443 then "https" else "http";
      in "${scheme}://${access.host}:${toString access.port}";
    };
    domain = mkOption {
      type = str;
      default = "idp.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "freeipa.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "freeipa.tail.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
      default = 443;
    };
    ldapPort = mkOption {
      type = port;
      default = 636;
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = virtualHosts.${access.domain}.useACMEHost;
    };
  };
  config = {
    services.nginx = {
      access.ldap = {
        enable = mkDefault true;
        host = mkDefault access.host;
        port = mkDefault access.ldapPort;
        useACMEHost = mkDefault access.useACMEHost;
      };
      virtualHosts = {
        ${access.domain} = {
          inherit locations;
        };
        ${access.localDomain} = {
          inherit (virtualHosts.${access.domain}) useACMEHost;
          addSSL = mkDefault (access.useACMEHost != null || virtualHosts.${access.domain}.forceSSL);
          local.enable = true;
          inherit locations;
        };
        ${access.tailDomain} = mkIf tailscale.enable {
          inherit (virtualHosts.${access.domain}) useACMEHost;
          addSSL = mkDefault (access.useACMEHost != null || virtualHosts.${access.domain}.forceSSL);
          local.enable = true;
          inherit locations;
        };
        ${ldap.domain} = { config, ... }: {
          useACMEHost = mkDefault virtualHosts.${access.domain}.useACMEHost;
          addSSL = mkDefault (config.useACMEHost != null);
          globalRedirect = access.domain;
        };
        ${ldap.localDomain} = {
          inherit (virtualHosts.${ldap.domain}) useACMEHost addSSL;
          globalRedirect = access.localDomain;
          local.enable = true;
        };
        ${ldap.tailDomain} = mkIf tailscale.enable {
          inherit (virtualHosts.${ldap.domain}) useACMEHost addSSL;
          globalRedirect = access.tailDomain;
          local.enable = true;
        };
      };
    };

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
