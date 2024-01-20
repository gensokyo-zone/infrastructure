{
  meta,
  lib,
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
    nixos.access.gensokyo
    nixos.access.zigbee2mqtt
    nixos.access.home-assistant
    nixos.vouch
    nixos.kanidm
    nixos.mosquitto
    nixos.home-assistant
    nixos.zigbee2mqtt
    nixos.syncplay
    ./cloudflared.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;
  networking.access.static.ipv4 = "10.1.1.39";

  system.stateVersion = "23.11";
}
