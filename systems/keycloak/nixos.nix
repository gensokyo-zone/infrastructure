{meta, config, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.keycloak
    nixos.cloudflared
    nixos.vouch
  ];

  services.cloudflared = let
    tunnelId = "c9a4b8c9-42d9-4566-8cff-eb63ca26809d";
    inherit (config.services) keycloak vouch-proxy;
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-keycloak.path;
      ingress = {
        ${keycloak.settings.hostname} = assert keycloak.enable; let
          scheme = if keycloak.sslCertificate != null then "https" else "http";
          port = keycloak.settings."${scheme}-port";
        in {
          service = "${scheme}://localhost:${toString port}";
          originRequest.${if scheme == "https" then "noTLSVerify" else null} = true;
        };
        ${vouch-proxy.domain}.service = assert vouch-proxy.enable; "http://localhost:${toString vouch-proxy.settings.vouch.port}";
      };
    };
  };
  sops.secrets.cloudflared-tunnel-keycloak = {
    owner = config.services.cloudflared.user;
  };

  sops.defaultSopsFile = ./secrets.yaml;

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:AC";
      Type = "ether";
    };
    address = ["10.1.1.48/24"];
    gateway = ["10.1.1.1"];
    DHCP = "no";
  };

  system.stateVersion = "23.11";
}