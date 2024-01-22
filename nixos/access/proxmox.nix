{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.strings) escapeRegex;
  inherit (lib.lists) singleton optional;
  inherit (config.services) tailscale;
  proxyPass = "https://reisen.local.gensokyo.zone:8006/";
  unencrypted = pkgs.mkSnakeOil {
    name = "prox-local-cert";
    domain = singleton "prox.local.${config.networking.domain}"
      ++ optional tailscale.enable "prox.tail.${config.networking.domain}";
  };
  sslCertificate = unencrypted.fullchain;
  sslCertificateKey = unencrypted.key;
in {
  services.nginx.virtualHosts."prox.${config.networking.domain}" = {
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
  };
  services.nginx.virtualHosts."prox.local.${config.networking.domain}" = {
    local.enable = mkDefault true;
    forceSSL = mkDefault true;
    inherit sslCertificate sslCertificateKey;
    locations."/" = {
      proxy.websocket.enable = true;
      inherit proxyPass;
    };
  };
  services.nginx.virtualHosts."prox.tail.${config.networking.domain}" = mkIf tailscale.enable {
    local.enable = mkDefault true;
    inherit sslCertificate sslCertificateKey;
    locations."/" = {
      proxy.websocket.enable = true;
      inherit proxyPass;
    };
  };

  sops.secrets.access-proxmox = {
    sopsFile = mkDefault ../secrets/access-proxmox.yaml;
    owner = config.services.nginx.user;
    group = config.services.nginx.group;
  };
}
