{
  config,
  meta,
  ...
}: {
  imports = let
    inherit (meta) nixos;
  in [
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
  ];

  services.nginx = {
    virtualHosts = {
      zigbee2mqtt.proxied.enable = "cloudflared";
      grocy.proxied.enable = "cloudflared";
      barcodebuddy.proxied.enable = "cloudflared";
    };
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
