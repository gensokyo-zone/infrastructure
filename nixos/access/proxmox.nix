{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.strings) escapeRegex;
  inherit (lib.lists) singleton optional;
  inherit (config.services) nginx tailscale;
  inherit (nginx) virtualHosts;
  access = config.services.nginx.access.proxmox;
  proxyPass = "https://reisen.local.gensokyo.zone:8006/";
  unencrypted = pkgs.mkSnakeOil {
    name = "prox-local-cert";
    domain = singleton "prox.local.${config.networking.domain}"
      ++ optional tailscale.enable "prox.tail.${config.networking.domain}";
  };
  sslHost = { config, ... }: {
    sslCertificate = mkIf (!config.enableACME && config.useACMEHost == null) unencrypted.fullchain;
    sslCertificateKey = mkIf (!config.enableACME && config.useACMEHost == null) unencrypted.key;
  };
in {
  options.services.nginx.access.proxmox = with lib.types; {
    domain = mkOption {
      type = str;
      default = "prox.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "prox.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "prox.tail.${config.networking.domain}";
    };
  };
  config.services.nginx.virtualHosts = let
    locations."/" = {
      extraConfig = ''
        if ($http_x_forwarded_proto = http) {
          return 302 https://$host$request_uri;
        }

        set $prox_prefix ''';
        include ${config.sops.secrets.access-proxmox.path};
        if ($request_uri ~ "^/([^/]+).*") {
          set $prox_prefix $1;
        }
        if ($request_uri ~ "^/(pve2/.*|pwt/.*|api2/.*|xtermjs/.*|[^/]+\.js.*)") {
          rewrite /(.*) /prox/$1 last;
        }
        if ($http_referer ~ "^https://prox\.${escapeRegex config.networking.domain}/([^/]+)/$") {
          set $prox_prefix $1;
        }
        if ($prox_prefix != $prox_expected) {
          return 501;
        }
        set $prox_plain ''';
        if ($request_uri ~ "^/([^/]+)$") {
          set $prox_plain $1;
        }
        if ($prox_plain = $prox_expected) {
          return 302 https://$host/$prox_plain/;
        }
        if ($prox_plain != ''') {
          rewrite /(.*) /prox/$1 last;
        }
        rewrite /[^/]+/(.*) /prox/$1;
        rewrite /[^/]+$ /prox/;
      '';
    };
    locations."/prox/" = {
      inherit proxyPass;
      extraConfig = ''
        internal;
      '';
    };
    locations."/prox/api2/" = {
      proxy.websocket.enable = true;
      proxyPass = "${proxyPass}api2/";
      extraConfig = ''
        internal;
      '';
    };
  in {
    ${access.domain} = {
      inherit locations;
    };
    ${access.localDomain} = mkMerge [ {
      inherit (virtualHosts.${access.domain}) useACMEHost;
      local.enable = mkDefault true;
      forceSSL = mkDefault true;
      locations."/" = {
        proxy.websocket.enable = true;
        inherit proxyPass;
      };
    } sslHost ];
    ${access.tailDomain} = mkIf tailscale.enable (mkMerge [ {
      inherit (virtualHosts.${access.domain}) useACMEHost;
      addSSL = mkDefault true;
      local.enable = mkDefault true;
      locations."/" = {
        proxy.websocket.enable = true;
        inherit proxyPass;
      };
    } sslHost ]);
  };

  config.sops.secrets.access-proxmox = {
    sopsFile = mkDefault ../secrets/access-proxmox.yaml;
    owner = config.services.nginx.user;
    inherit (nginx) group;
  };
}
