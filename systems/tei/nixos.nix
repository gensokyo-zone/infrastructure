{
  config,
  lib,
  meta,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (config.services) kanidm mosquitto home-assistant;
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
    nixos.vouch
    nixos.kanidm
    nixos.mosquitto
    nixos.home-assistant
    nixos.zigbee2mqtt
    nixos.syncplay
    ./cloudflared.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  services.home-assistant.homekit.openFirewall = true;

  services.kanidm = {
    package =
      lib.warnIf
      (pkgs.kanidm.version != "1.1.0-rc.15")
      "upstream kanidm may have localhost oauth2 support now!"
      pkgs.kanidm-develop;
  };

  networking.firewall = {
    interfaces.local.allowedTCPPorts = mkMerge [
      (mkIf kanidm.enableServer [
        kanidm.server.frontend.port
        (mkIf kanidm.server.ldap.enable kanidm.server.ldap.port)
      ])
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
