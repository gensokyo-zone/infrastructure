{
  config,
  meta,
  access,
  ...
}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.tailscale
    nixos.cloudflared
    nixos.nginx
    nixos.access.proxmox
    nixos.access.plex
  ];

  sops.secrets.cloudflared-tunnel-hakurei = {
    owner = config.services.cloudflared.user;
  };

  services.cloudflared = let
    tunnelId = "964121e3-b3a9-4cc1-8480-954c4728b604";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-hakurei.path;
      ingress = {
        "prox.${config.networking.domain}".service = "http://localhost";
      };
    };
  };

  services.nginx.access = {
    plex.url = let
      system = access.systemFor "mediabox";
    in "http://${system.networking.access.hostnameForNetwork.local}:32400";
  };

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:A7";
      Type = "ether";
    };
    address = [ "10.1.1.41/24" ];
    gateway = [ "10.1.1.1" ];
    DHCP = "no";
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
