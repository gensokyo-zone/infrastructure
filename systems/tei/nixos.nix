{
  config,
  lib,
  meta,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (config.services) mosquitto home-assistant;
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
    nixos.access.zigbee2mqtt
    nixos.access.home-assistant
    nixos.access.unifi
    nixos.unifi
    nixos.mosquitto
    nixos.home-assistant
    nixos.zigbee2mqtt
    nixos.syncplay
    ./cloudflared.nix
  ];

  services.nginx = let
    inherit (config.services.nginx) access;
  in {
    virtualHosts = {
      ${access.zigbee2mqtt.domain} = {
        local.denyGlobal = true;
      };
    };
  };

  sops.defaultSopsFile = ./secrets.yaml;

  networking.firewall = {
    interfaces.local.allowedTCPPorts = mkMerge [
      (mkIf home-assistant.enable [
        home-assistant.config.http.server_port
      ])
      (mkIf mosquitto.enable (map (
          listener:
            listener.port
        )
        mosquitto.listeners))
    ];
  };

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:CC:66:57";
      Type = "ether";
    };
    address = ["10.1.1.39/24"];
    gateway = ["10.1.1.1"];
    DHCP = "no";
  };

  system.stateVersion = "23.11";
}
