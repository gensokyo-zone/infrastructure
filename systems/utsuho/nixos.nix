{
  meta,
  access,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge;
  inherit (config.services) nginx;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.int
    nixos.ipa
    nixos.cloudflared
    nixos.nginx
    nixos.access.unifi
    nixos.access.prometheus
    nixos.access.grafana
    nixos.access.loki
    nixos.unifi
    nixos.dnsmasq
    nixos.mosquitto
    nixos.monitoring
  ];

  services.cloudflared = let
    inherit (nginx) virtualHosts;
    inherit (config.networking) domain;
    tunnelId = "28bcd3fc-3467-4997-806b-546ba9995028";
    gatus'system = access.systemForService "gatus";
    inherit (gatus'system.exports.services) gatus;
    ingress = {
      "${gatus.id}.${domain}".service = access.proxyUrlFor {
        system = gatus'system;
        service = gatus;
      };
    };
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-utsuho.path;
      ingress = mkMerge [
        ingress
        (virtualHosts.unifi.proxied.cloudflared.getIngress {})
        (virtualHosts.prometheus.proxied.cloudflared.getIngress {})
        (virtualHosts.grafana.proxied.cloudflared.getIngress {})
        (virtualHosts.loki.proxied.cloudflared.getIngress {})
      ];
    };
  };

  services.nginx = {
    proxied.enable = true;
    virtualHosts = {
      unifi.proxied.enable = "cloudflared";
      prometheus.proxied.enable = "cloudflared";
      grafana.proxied.enable = "cloudflared";
      loki.proxied.enable = "cloudflared";
    };
  };

  sops.secrets.cloudflared-tunnel-utsuho = {
    owner = "cloudflared";
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
