{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) nginx home-assistant;
  name.shortServer = mkDefault "home";
  listen' = {
    http = {};
    https.ssl = true;
    hass = {
      enable = !home-assistant.enable;
      port = mkDefault home-assistant.config.http.server_port;
      extraParameters = ["default_server"];
    };
  };
  upstreamName = "home-assistant'access";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault home-assistant.enable;
        addr = mkDefault "localhost";
        port = mkIf home-assistant.enable (mkDefault home-assistant.config.http.server_port);
      };
      service = {upstream, ...}: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService = {
          name = "home-assistant";
        };
      };
    };
    virtualHosts = let
      vouchHost = { config, ... }: {
        vouch = {
          requireAuth = mkDefault false;
          auth.lua = {
            enable = mkDefault true;
            accessRequest = ''
              ngx.ctx.auth_res = ngx.location.capture("${config.vouch.auth.requestLocation}")
              if ngx.ctx.auth_res.status == ngx.HTTP_OK then
                local vouch_user = ngx.re.match(ngx.ctx.auth_res.header["X-Vouch-User"], [[^([^@]+)@.*$]])
                ngx.var["hass_user"] = vouch_user[1]
              end
            '';
          };
        };
        extraConfig = ''
          set $hass_user "";
        '';
      };
      headers.set.X-Hass-User = mkDefault "$hass_user";
      copyFromVhost = mkDefault "home-assistant";
      locations = {
        "/" = {
          proxy = {
            inherit headers;
            enable = true;
          };
        };
        # TODO: restrict to "/auth/authorize" and "/auth/login_flow" only..?
        "/auth/" = { virtualHost, config, ... }: {
          proxy = {
            inherit headers;
            enable = true;
          };
          vouch = mkIf virtualHost.vouch.enable {
            requireAuth = true;
          };
        };
        "/api/websocket" = {
          proxy = {
            inherit headers;
            enable = true;
            websocket.enable = true;
          };
        };
      };
    in {
      home-assistant = { ... }: {
        imports = [ vouchHost ];
        inherit name locations;
        proxy.upstream = mkDefault upstreamName;
      };
      home-assistant'local = { ... }: {
        imports = [ vouchHost ];
        vouch.enable = mkDefault nginx.virtualHosts.home-assistant.vouch.enable;
        inherit name listen' locations;
        ssl.cert = {
          inherit copyFromVhost;
        };
        proxy = {
          inherit copyFromVhost;
        };
        local.enable = mkDefault true;
      };
    };
  };
  config.services.home-assistant = {
    reverseProxy = {
      enable = mkDefault true;
      auth = {
        enable = mkIf (nginx.virtualHosts.home-assistant.enable && nginx.virtualHosts.home-assistant.vouch.enable) true;
        userHeader = "X-Hass-User";
      };
    };
  };
  config.networking.firewall.allowedTCPPorts = let
    inherit (nginx.virtualHosts.home-assistant'local) listen';
  in
    mkIf nginx.virtualHosts.home-assistant'local.enable [
      (mkIf listen'.hass.enable listen'.hass.port)
    ];
}
