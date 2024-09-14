{
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) bindToAddress;
  inherit (lib.modules) mkIf mkBefore mkDefault;
  inherit (lib.strings) escapeRegex;
  inherit (config.services) tailscale;
  cfg = config.services.nextjs-ollama-llm-ui;
  upstreamName = "ollama'nextjs";
in {
  services.nextjs-ollama-llm-ui = {
    #ollamaUrl = mkDefault "https://${virtualHost.serverName}/ollama";
  };
  services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault cfg.enable;
        addr = mkDefault (bindToAddress {} cfg.hostname);
        port = mkIf cfg.enable (mkDefault cfg.port);
      };
    };
    virtualHosts = let
      name.shortServer = "lm";
      copyFromVhost = mkDefault "llama";
      vouch = {
        enable = true;
        requireAuth = false;
      };
      subFilterLocation = {virtualHost, ...}:
        mkIf (virtualHost.locations ? "/ollama/") {
          proxy.headers.set.Accept-Encoding = "";
          extraConfig = ''
            sub_filter_once off;
            sub_filter_types application/javascript;
            sub_filter '${cfg.ollamaUrl}' '/ollama';
          '';
        };
      proxyLocation = {
        imports = [subFilterLocation];
        proxy = {
          enable = true;
          upstream = mkDefault upstreamName;
        };
      };
      locations = {
        "~ ^/llama$" = {
          return = mkDefault "302 /llama/";
        };
        "/llama/" = {virtualHost, ...}: {
          imports = [proxyLocation];
          vouch.requireAuth = mkIf virtualHost.vouch.enable true;
          proxy.path = "/";
        };
        "/_next/" = {virtualHost, ...}: {
          imports = [proxyLocation];
          vouch.requireAuth = mkIf virtualHost.vouch.enable true;
        };
        "/_next/static/" = _: {
          imports = [proxyLocation];
        };
        "~ '^/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'" = {
          return = mkDefault "302 /llama$request_uri";
        };
        "/" = {virtualHost, ...}: {
          extraConfig = mkBefore ''
            if ($http_referer ~ '^https?://${escapeRegex virtualHost.serverName}/llama/') {
              return 302 /llama$request_uri;
            }
          '';
          return = mkDefault "404";
        };
      };
    in {
      llama = {
        inherit name locations vouch;
        ssl.force = true;
      };
      llama'local = {
        inherit locations;
        name = {
          inherit (name) shortServer;
          includeTailscale = false;
        };
        ssl.cert = {
          inherit copyFromVhost;
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
