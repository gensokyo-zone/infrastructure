{
  meta,
  config,
  access,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.ipa
    nixos.keycloak
    nixos.vaultwarden
    nixos.cloudflared
    nixos.vouch.gensokyo
    nixos.nginx
    nixos.access.vaultwarden
  ];

  services.cloudflared = let
    tunnelId = "c9a4b8c9-42d9-4566-8cff-eb63ca26809d";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-keycloak.path;
      ingress = let
        inherit (config.services) nginx;
        inherit (config.networking) domain;
        keycloak'system = access.systemForService "keycloak";
        inherit (keycloak'system.exports.services) keycloak;
        vouch'system = access.systemForServiceId "login";
        inherit (vouch'system.exports.services) vouch-proxy;
        ingress = {
          "${keycloak.id}.${domain}" = let
            portName =
              if keycloak.ports.https.enable
              then "https"
              else "http";
          in {
            service = access.proxyUrlFor {
              system = keycloak'system;
              service = keycloak;
              inherit portName;
            };
            originRequest.${
              if keycloak.ports.${portName}.protocol == "https"
              then "noTLSVerify"
              else null
            } =
              true;
          };
          "${vouch-proxy.id}.${domain}" = {
            service = access.proxyUrlFor {
              system = vouch'system;
              service = vouch-proxy;
            };
          };
        };
      in
        mkMerge [
          ingress
          (nginx.virtualHosts.vaultwarden.proxied.cloudflared.getIngress {})
        ];
    };
  };

  services.nginx = {
    proxied.enable = true;
    virtualHosts = {
      vaultwarden.proxied.enable = "cloudflared";
    };
  };

  sops.secrets.cloudflared-tunnel-keycloak = {
    owner = "cloudflared";
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
