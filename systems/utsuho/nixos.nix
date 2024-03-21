{meta, config, access, ...}: let
  inherit (config.services.nginx) virtualHosts;
  tei = access.nixosFor "tei";
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.cloudflared
    nixos.nginx
    nixos.access.unifi
    nixos.unifi
  ];

  services.cloudflared = let
    tunnelId = "28bcd3fc-3467-4997-806b-546ba9995028";
    inherit (config.services) unifi;
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-utsuho.path;
      ingress = {
        ${virtualHosts.unifi.serverName} = assert unifi.enable; {
          service = "http://localhost";
        };
      };
    };
  };

  services.nginx = {
    virtualHosts = {
      unifi.proxied.enable = "cloudflared";
    };
  };

  sops.secrets.cloudflared-tunnel-utsuho = {
    owner = config.services.cloudflared.user;
  };

  sops.defaultSopsFile = ./secrets.yaml;

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:A6";
      Type = "ether";
    };
    address = ["10.1.1.38/24"];
    gateway = ["10.1.1.1"];
    DHCP = "no";
  };

  system.stateVersion = "23.11";
}
