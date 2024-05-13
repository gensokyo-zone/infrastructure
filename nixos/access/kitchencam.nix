{
  config,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkDefault;
  inherit (lib.attrsets) mapAttrs;
  inherit (config.services) nginx;
  system = access.systemForServiceId "kitchen";
  inherit (system.exports.services) motion;
in {
  config.services.nginx = {
    virtualHosts = let
      url = access.proxyUrlFor {
        inherit system;
        service = motion;
      };
      streamUrl = access.proxyUrlFor {
        inherit system;
        service = motion;
        portName = "stream";
      };
      extraConfig = ''
        proxy_redirect off;
        proxy_buffering off;
      '';
      locations = {
        "/" = {
          proxyPass = mkDefault url;
        };
        "~ ^/[0-9]+/(stream|motion|substream|current|source|status\\.json)$" = {
          proxyPass = mkDefault streamUrl;
          inherit extraConfig;
        };
        "~ ^/(stream|motion|substream|current|source|cameras\\.json|status\\.json)$" = {
          proxyPass = mkDefault streamUrl;
          inherit extraConfig;
        };
      };
      listen' = {
        http = {};
        https.ssl = true;
        stream = {
          enable = mkDefault motion.ports.stream.enable;
          port = mkDefault motion.ports.stream.port;
        };
      };
      name.shortServer = mkDefault "kitchen";
    in {
      kitchencam = {
        inherit name locations listen';
        vouch.enable = true;
      };
      kitchencam'local = {
        inherit name listen';
        ssl.cert.copyFromVhost = "kitchencam";
        local.enable = true;
        locations = mapAttrs (name: location:
          location
          // {
            proxyPass = mkDefault nginx.virtualHosts.kitchencam.locations.${name}.proxyPass;
          })
        locations;
      };
    };
  };
  config.networking.firewall.allowedTCPPorts = let
    inherit (nginx.virtualHosts.kitchencam) listen';
  in [
    listen'.stream.port
  ];
}
