{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  inherit (config.services) nginx;
  cfg = config.services.deluge;
  upstreamName = "deluge'access";
  upstreamName'daemon = "deluge'daemon'access";
  locations."/".proxy.enable = true;
  name.shortServer = mkDefault "deluge";
  copyFromVhost = mkDefault "deluge";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = mkIf (cfg.enable && cfg.web.enable) {
        enable = mkDefault true;
        addr = mkDefault "127.0.0.1";
        port = mkDefault cfg.web.port;
      };
      access = {upstream, ...}: {
        enable = mkDefault (!upstream.servers.local.enable or false);
        accessService = {
          name = "deluge";
          port = "web";
          getAddressFor = mkDefault "getAddress4For";
        };
      };
    };
    virtualHosts = {
      deluge = {
        inherit name locations;
        ssl.force = mkDefault true;
        proxy.upstream = mkDefault upstreamName;
        vouch.enable = mkDefault true;
      };
      deluge'local = {
        inherit name locations;
        ssl = {
          force = mkDefault true;
          cert = {
            inherit copyFromVhost;
          };
        };
        local.enable = true;
        proxy = {
          inherit copyFromVhost;
        };
      };
    };
    stream = {
      upstreams.${upstreamName'daemon} = {
        enable = mkDefault (!cfg.enable);
        servers = {
          local = mkIf cfg.enable {
            enable = mkDefault true;
            addr = mkDefault "127.0.0.1";
            port = mkDefault cfg.config.daemon_port;
          };
          access = {upstream, ...}: {
            enable = mkDefault (!upstream.servers.local.enable or false);
            accessService = {
              name = "deluge";
              getAddressFor = mkDefault "getAddress4For";
            };
          };
        };
      };
      servers.deluge'local = {config, ...}: let
        upstream = nginx.stream.upstreams.${config.proxy.upstream};
      in {
        enable = mkDefault upstream.enable;
        listen.daemon.port = mkOptionDefault upstream.servers.${upstream.defaultServerName}.port;
        local.enable = true;
        proxy.upstream = mkDefault upstreamName'daemon;
      };
    };
  };
  config.networking.firewall = let
    daemonServer = nginx.stream.servers.deluge'local;
  in
    mkIf daemonServer.enable {
      interfaces.local.allowedTCPPorts = [
        daemonServer.listen.daemon.port
      ];
    };
}
