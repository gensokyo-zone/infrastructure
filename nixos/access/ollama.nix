{
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) bindToAddress;
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) tailscale;
  cfg = config.services.ollama;
  requestTimeout = "${toString (60 * 60)}s";
  upstreamName = "ollama'access";
in {
  services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault cfg.enable;
        addr = mkDefault (bindToAddress {} cfg.host);
        port = mkIf cfg.enable (mkDefault cfg.port);
      };
      service = {upstream, ...}: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService.name = "ollama";
        #settings.fail_timeout = mkDefault requestTimeout;
      };
    };
    virtualHosts = let
      name.shortServer = "lm";
      copyFromVhost = mkDefault "llama";
      locations = {
        "/ollama/" = {virtualHost, ...}: {
          vouch.requireAuth = mkIf virtualHost.vouch.enable (mkDefault true);
          proxy = {
            enable = true;
            upstream = upstreamName;
            path = "/";
          };
          extraConfig = ''
            proxy_buffering off;
            proxy_read_timeout ${requestTimeout};
          '';
          headers.set.Access-Control-Allow-Origin = "https://${virtualHost.serverName}/llama/";
        };
        "/".return = mkDefault "404";
      };
      vouch = {
        enable = true;
        requireAuth = false;
      };
    in {
      llama = {
        inherit name locations vouch;
        ssl.force = true;
      };
      llama'local = {
        inherit locations vouch;
        name = {
          inherit (name) shortServer;
          includeTailscale = false;
        };
        ssl = {
          force = true;
          cert = {
            inherit copyFromVhost;
          };
        };
        local.enable = mkDefault true;
      };
      llama'tail = {
        inherit locations;
        enable = mkDefault tailscale.enable;
        name = {
          inherit (name) shortServer;
          qualifier = mkDefault "tail";
        };
        ssl.cert.copyFromVhost = "llama'local";
        local.enable = mkDefault true;
      };
    };
  };
}
