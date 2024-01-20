{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.strings) escapeRegex;
  proxyPass = "https://reisen.local.gensokyo.zone:8006/";
in {
  services.nginx.virtualHosts."prox.${config.networking.domain}" = {
    locations."/" = {
      extraConfig = ''
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
        if ($request_uri ~ "^/([^/]+)") {
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
      proxyPass = "${proxyPass}api2/";
      extraConfig = ''
        internal;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };
  };
  services.nginx.virtualHosts."prox.local.${config.networking.domain}" = {
    local.enable = mkDefault true;
    locations."/" = {
      inherit proxyPass;
    };
  };
  services.nginx.virtualHosts."prox.tail.${config.networking.domain}" = mkIf config.services.tailscale.enable {
    local.enable = mkDefault true;
    locations."/" = {
      inherit proxyPass;
    };
  };

  sops.secrets.access-proxmox = {
    sopsFile = mkDefault ../secrets/access-proxmox.yaml;
    owner = config.services.nginx.user;
    group = config.services.nginx.group;
  };
}
