{
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

  services.kanidm = {
    server.openFirewall = true;
  };

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:CC:66:57";
      Type = "ether";
    };
    address = [ "10.1.1.39/24" ];
    gateway = [ "10.1.1.1" ];
    DHCP = "no";
  };

  system.stateVersion = "23.11";
}
