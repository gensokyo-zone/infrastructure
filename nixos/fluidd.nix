{
  config,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) domain;
  inherit (lib.modules) mkIf mkDefault mkForce;
  inherit (lib.strings) removePrefix;
  cfg = config.services.fluidd;
  serverName = "@fluidd_internal";
  virtualHost = config.services.nginx.virtualHosts.${cfg.hostName};
in {
  services = {
    fluidd = {
      enable = mkDefault true;
      hostName = mkDefault "print.local.${domain}"; # TODO: serverName?
      nginx.locations = let
        inherit (config.services.motion.cameras) printercam;
        inherit (printercam.settings) camera_id;
      in {
        "/webcam".proxyPass = "https://kitchen.local.${domain}/${toString camera_id}/stream";
        "/webcam/current".proxyPass = "https://kitchen.local.${domain}/${toString camera_id}/current";
      };
    };
    nginx = mkIf cfg.enable {
      proxied.enable = true;
      upstreams.fluidd-apiserver = let
        moonraker = access.proxyUrlFor {
          serviceName = "moonraker";
          scheme = "";
        };
      in
        mkForce {
          servers.${moonraker} = {};
        };
      virtualHosts = {
        ${cfg.hostName} = {
          enable = false;
        };
        ${serverName} = {
          # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/web-apps/fluidd.nix
          # XXX: non-@ host required for gatus to work
          serverAliases = [(removePrefix "@" serverName)];
          proxied.enable = true;
          # TODO: proxy.upstream = "fluidd-apiserver";
          proxy.url = "http://fluidd-apiserver";
          root = virtualHost.root;
          locations = {
            "/" = {
              inherit (virtualHost.locations."/") index tryFiles;
            };
            "/index.html" = {
              extraConfig = ''
                add_header Cache-Control "no-store, no-cache, must-revalidate";
              '';
            };
            "/websocket" = {
              proxy = {
                enable = true;
                websocket.enable = true;
              };
            };
            "/webcam" = {
              inherit (virtualHost.locations."/webcam") proxyPass;
            };
            "/webcam/current" = {
              inherit (virtualHost.locations."/webcam/current") proxyPass;
            };
            "~ ^/(printer|api|access|machine|server)/" = {
              proxy = {
                enable = true;
                websocket.enable = true;
                path = "$request_uri";
              };
            };
          };
        };
      };
    };
  };
}
