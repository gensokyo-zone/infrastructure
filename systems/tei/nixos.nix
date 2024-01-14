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
    nixos.vouch
    nixos.kanidm
    nixos.mosquitto
    nixos.syncplay
    ./cloudflared.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  services.nginx.access.zigbee2mqtt = let
    inherit (meta.network.nodes) tewi;
    z2m = tewi.services.zigbee2mqtt;
  in {
    inherit (z2m) domain;
    inherit (z2m.settings.frontend) port;
    host = tewi.networking.access.hostnameForNetwork.tail;
  };

  system.stateVersion = "23.11";
}
