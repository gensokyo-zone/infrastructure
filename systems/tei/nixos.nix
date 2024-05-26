{
  config,
  meta,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.lists) optional;
  hassVouchAuth = false;
  hassVouch = false;
in {
  imports = let
    inherit (meta) nixos;
  in
    [
      nixos.reisen-ct
      nixos.sops
      nixos.tailscale
      nixos.cloudflared
      nixos.postgres
      nixos.nginx
      nixos.access.zigbee2mqtt
      nixos.access.grocy
      nixos.access.barcodebuddy
      nixos.home-assistant
      nixos.zigbee2mqtt
      nixos.syncplay
      nixos.grocy
      nixos.barcodebuddy
      ./cloudflared.nix
    ]
    ++ optional hassVouchAuth nixos.access.home-assistant;

  services.nginx = {
    proxied.enable = true;
    virtualHosts = {
      zigbee2mqtt.proxied.enable = "cloudflared";
      grocy.proxied.enable = "cloudflared";
      barcodebuddy.proxied.enable = "cloudflared";
      home-assistant = mkIf hassVouchAuth {
        proxied.enable = "cloudflared";
        vouch.enable = mkIf hassVouch true;
      };
    };
  };
  services.home-assistant = mkIf hassVouchAuth {
    reverseProxy.auth.enable = true;
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
