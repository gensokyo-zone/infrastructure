{
  meta,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  hassVouch = false;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.reisen-ct
    nixos.sops
    nixos.tailscale
    nixos.cloudflared
    nixos.postgres
    nixos.nginx
    nixos.adb
    nixos.access.home-assistant
    nixos.access.zigbee2mqtt
    nixos.access.grocy
    nixos.access.barcodebuddy
    nixos.access.nfandroidtv
    nixos.home-assistant
    nixos.zigbee2mqtt
    nixos.grocy
    nixos.barcodebuddy
    nixos.taskchampion
    ./cloudflared.nix
  ];

  services.nginx = {
    proxied.enable = true;
    virtualHosts = {
      zigbee2mqtt.proxied.enable = "cloudflared";
      grocy.proxied.enable = "cloudflared";
      barcodebuddy.proxied.enable = "cloudflared";
      home-assistant = {
        proxied.enable = "cloudflared";
        vouch.enable = mkIf hassVouch true;
      };
    };
  };
  services.home-assistant = {
    #reverseProxy.auth.enable = true;
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
