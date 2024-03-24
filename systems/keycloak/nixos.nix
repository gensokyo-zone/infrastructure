{meta, config, ...}: {
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
    inherit (config.services) keycloak vouch-proxy;
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-keycloak.path;
      ingress = let
        keycloakHost = if keycloak.settings.hostname != null then keycloak.settings.hostname else "sso.${config.networking.domain}";
        keyCloakScheme = if keycloak.sslCertificate != null then "https" else "http";
        keycloakPort = keycloak.settings."${keyCloakScheme}-port";
      in {
        ${keycloakHost} = assert keycloak.enable; {
          service = "${keyCloakScheme}://localhost:${toString keycloakPort}";
          originRequest.${if keyCloakScheme == "https" then "noTLSVerify" else null} = true;
        };
        ${vouch-proxy.domain}.service = assert vouch-proxy.enable; "http://localhost:${toString vouch-proxy.settings.vouch.port}";
      };
    };
  };

  sops.secrets.cloudflared-tunnel-keycloak = {
    owner = config.services.cloudflared.user;
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
