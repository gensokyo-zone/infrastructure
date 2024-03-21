{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge mkDefault;
  inherit (lib.strings) escapeRegex;
  inherit (config.services) nginx tailscale;
  proxyPass = "https://reisen.local.${config.networking.domain}:8006/";
in {
  config.services.nginx.virtualHosts = let
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
        if ($http_referer ~ "^https://${escapeRegex nginx.virtualHosts.prox.serverName}/([^/]+)/$") {
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
    extraConfig = ''
      client_max_body_size 16384M;
    '';
    name.shortServer = mkDefault "prox";
  in {
    prox = {
      inherit name locations extraConfig;
      ssl.force = true;
    };
    prox'local = {
      name = {
        inherit (name) shortServer;
        includeTailscale = false;
      };
      ssl = {
        force = true;
        cert.copyFromVhost = "prox";
      };
      local.enable = mkDefault true;
      locations."/" = {
        proxy.websocket.enable = true;
        inherit proxyPass extraConfig;
      };
    };
    prox'tail = {
      enable = mkDefault tailscale.enable;
      name = {
        inherit (name) shortServer;
        qualifier = mkDefault "tail";
      };
      ssl.cert.copyFromVhost = "prox'local";
      local.enable = mkDefault true;
      locations."/" = {
        proxy.websocket.enable = true;
        inherit proxyPass extraConfig;
      };
    };
  };

  config.sops.secrets.access-proxmox = {
    sopsFile = mkDefault ../secrets/access-proxmox.yaml;
    owner = nginx.user;
    inherit (nginx) group;
  };
}
