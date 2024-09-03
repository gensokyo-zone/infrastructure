{
  config,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.attrsets) mapAttrs;
  inherit (config.services) nginx;
  system = access.systemForServiceId "kitchen";
  inherit (system.exports.services) motion;
in {
  config.services.nginx = {
    virtualHosts = let
      # TODO: use upstreams for this!
      url = access.proxyUrlFor {
        inherit system;
        service = motion;
      };
      streamUrl = access.proxyUrlFor {
        inherit system;
        service = motion;
        portName = "stream";
      };
      mkSubFilter = port: ''
        sub_filter '${port.protocol}://$host:${toString port.port}/' '/';
      '';
      extraConfig = ''
        proxy_redirect off;
        proxy_buffering off;
        set $args "";
      '';
      locations = {
        "/" = {
          proxyPass = mkDefault url;
          extraConfig = ''
            sub_filter_once off;
            ${mkSubFilter motion.ports.stream}
            ${mkSubFilter motion.ports.default}
          '';
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
          enable = false;
          #enable = mkDefault motion.ports.stream.enable;
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
  in
    mkIf listen'.stream.enable [
      listen'.stream.port
    ];
}
