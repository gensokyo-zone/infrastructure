{meta, config, access, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.ipa
    nixos.keycloak
    nixos.cloudflared
    nixos.vouch
  ];

  services.cloudflared = let
    tunnelId = "c9a4b8c9-42d9-4566-8cff-eb63ca26809d";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-keycloak.path;
      ingress = let
        keycloak'system = access.systemForService "keycloak";
        inherit (keycloak'system.exports.services) keycloak;
        vouch'system = access.systemForServiceId "login";
        inherit (vouch'system.exports.services) vouch-proxy;
      in {
        "${keycloak.id}.${config.networking.domain}" = let
          portName = if keycloak.ports.https.enable then "https" else "http";
        in {
          service = access.proxyUrlFor { system = keycloak'system; service = keycloak; inherit portName; };
          originRequest.${if keycloak.ports.${portName}.protocol == "https" then "noTLSVerify" else null} = true;
        };
        "${vouch-proxy.id}.${config.networking.domain}" = {
          service = access.proxyUrlFor { system = vouch'system; service = vouch-proxy; };
        };
      };
    };
  };

  sops.secrets.cloudflared-tunnel-keycloak = {
    owner = config.services.cloudflared.user;
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
