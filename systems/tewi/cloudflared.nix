{ pkgs, config, utils, lib, ... }: let
  inherit (lib) mapAttrsToList mapAttrs' nameValuePair splitString last singleton
    mkIf mkMerge mkForce;
  inherit (config) services;
  inherit (services.kanidm.serverSettings) domain;
  cfg = services.cloudflared;
  apartment = "131222b0-9db0-4168-96f5-7d45ec51c3be";
  shadowTunnel = {
    ${apartment}.ingress.deluge = {
      hostname._secret = config.sops.secrets.cloudflared-tunnel-apartment-deluge.path;
      service = "http://localhost:${toString services.deluge.web.port}";
    };
  };
in {
  sops.secrets.cloudflared-tunnel-apartment.owner = services.cloudflared.user;
  sops.secrets.cloudflared-tunnel-apartment-deluge.owner = services.cloudflared.user;
  services.cloudflared = {
    enable = true;
    tunnels = {
      ${apartment} = {
        credentialsFile = config.sops.secrets.cloudflared-tunnel-apartment.path;
        default = "http_status:404";
        ingress = mapAttrs' (prefix: nameValuePair "${prefix}${domain}") {
          "".service = "http://localhost:80";
          "home.".service = "http://localhost:${toString services.home-assistant.config.http.server_port}";
          "z2m.".service = "http://localhost:80";
          "login.".service = "http://localhost:${toString services.vouch-proxy.settings.vouch.port}";
          "id." = let
            inherit (services.kanidm.serverSettings) bindaddress;
            port = last (splitString ":" bindaddress);
          in {
            service = "https://127.0.0.1:${port}";
            originRequest.noTLSVerify = true;
          };
        };
      };
    };
  };
  systemd.services = let
    filterConfig = lib.filterAttrsRecursive (_: v: ! builtins.elem v [ null [ ] { } ]);
    mapIngress = hostname: ingress: {
      inherit hostname;
    } // filterConfig (filterConfig ingress);
  in mkIf cfg.enable (mapAttrs' (uuid: tunnel: let
    RuntimeDirectory = "cloudflared-tunnel-${uuid}";
    configPath = "/run/${RuntimeDirectory}/config.yml";
    settings = {
      tunnel = uuid;
      credentials-file = tunnel.credentialsFile;
      ingress = mapAttrsToList mapIngress tunnel.ingress
      ++ mapAttrsToList mapIngress shadowTunnel.${uuid}.ingress or { }
      ++ singleton { service = tunnel.default; };
    };
  in nameValuePair "cloudflared-tunnel-${uuid}" (mkMerge [
    {
      after = [ "tailscale-autoconnect.service" ];
      serviceConfig = {
        RestartSec = 10;
      };
    }
    (mkIf (shadowTunnel.${uuid} or { } != { }) {
      serviceConfig = {
        inherit RuntimeDirectory;
        ExecStart = mkForce [
          "${cfg.package}/bin/cloudflared tunnel --config=${configPath} --no-autoupdate run"
        ];
        ExecStartPre = [
          (pkgs.writeShellScript "cloudflared-tunnel-${uuid}-prepare" ''
            ${utils.genJqSecretsReplacementSnippet settings configPath}
          '')
        ];
      };
    })
  ])) cfg.tunnels);
}
