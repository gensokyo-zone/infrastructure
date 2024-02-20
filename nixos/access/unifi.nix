{
  config,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkDefault;
  inherit (config.services) nginx;
in {
  config.services.nginx = {
    virtualHosts = let
      extraConfig = ''
        proxy_redirect off;
        proxy_buffering off;
      '';
      name.shortServer = mkDefault "unifi";
      kTLS = mkDefault true;
    in {
      unifi = {
        inherit name extraConfig kTLS;
        vouch.enable = mkDefault true;
        ssl.force = mkDefault true;
        locations."/" = {
          proxyPass = mkDefault (access.proxyUrlFor { serviceName = "unifi"; portName = "management"; });
        };
      };
      unifi'local = {
        inherit name extraConfig kTLS;
        ssl.cert.copyFromVhost = "unifi";
        local.enable = true;
        locations."/" = {
          proxyPass = mkDefault nginx.virtualHosts.unifi.locations."/".proxyPass;
        };
      };
    };
  };
}
