{
  config,
  meta,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.lists) optional;
  hassOpenMetrics = true;
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
    ++ optional (hassVouchAuth || hassOpenMetrics) nixos.access.home-assistant;

  services.nginx = {
    proxied.enable = true;
    virtualHosts = {
      zigbee2mqtt.proxied.enable = "cloudflared";
      grocy.proxied.enable = "cloudflared";
      barcodebuddy.proxied.enable = "cloudflared";
      home-assistant = mkIf (hassVouchAuth || hassOpenMetrics) {
        proxied.enable = "cloudflared";
        vouch.enable = mkIf hassVouch true;
      };
    };
  };
  services.home-assistant = mkIf hassVouchAuth {
    reverseProxy.auth.enable = true;
  };

  assertions = let
    inherit (config.services) home-assistant;
  in [
    (mkIf home-assistant.enable {
      assertion = hassOpenMetrics != home-assistant.config.prometheus.requires_auth or true;
      message = "home-assistant.config.prometheus.requires_auth set incorrectly";
    })
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
