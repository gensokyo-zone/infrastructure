{
  meta,
  config,
  ...
}: let
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
    nixos.unifi
    nixos.dnsmasq
    nixos.mosquitto
    nixos.monitoring
  ];

  services.cloudflared = let
    inherit (nginx) virtualHosts;
    tunnelId = "28bcd3fc-3467-4997-806b-546ba9995028";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-utsuho.path;
      ingress = virtualHosts.unifi.proxied.cloudflared.getIngress {};
    };
  };

  services.nginx = {
    proxied.enable = true;
    virtualHosts = {
      unifi.proxied.enable = "cloudflared";
    };
  };

  sops.secrets.cloudflared-tunnel-utsuho = {
    owner = config.services.cloudflared.user;
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
