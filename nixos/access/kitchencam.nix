{
  config,
  gensokyo-zone,
  lib,
  access,
  ...
}: let
  inherit (gensokyo-zone.lib) mapDefaults;
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.attrsets) mapAttrs mergeAttrsList;
  inherit (config.services) nginx;
  system = access.systemForServiceId "kitchen";
  inherit (system.exports.services) motion;
  upstreamNameKitchen = "kitchencam'access";
  upstreamNamePrinter = "printercam'access";
in {
  config.services.nginx = {
    upstreams' = {
      ${upstreamNameKitchen}.servers.service = {
        accessService = {
          name = "motion";
          id = "kitchen";
        };
        settings.max_fails = 5;
      };
      "${upstreamNameKitchen}'stream".servers.service = let
        motionServer = nginx.upstreams'.${upstreamNameKitchen}.servers.service;
      in {
        accessService = {
          inherit (motionServer.accessService) name id;
          port = "stream";
        };
        settings = {
          inherit (motionServer.settings) max_fails;
        };
      };
      ${upstreamNamePrinter}.servers.service = {
        accessService = {
          name = "motion";
          id = "printercam";
        };
      };
      "${upstreamNamePrinter}'stream".servers.service = let
        motionServer = nginx.upstreams'.${upstreamNamePrinter}.servers.service;
      in {
        accessService = {
          inherit (motionServer.accessService) name id;
          port = "stream";
        };
      };
    };
    virtualHosts = let
      printerCams = [2];
      kitchenCams = [1 3 4];
      mkSubFilter = port: path: ''
        sub_filter '${port.protocol}://$host:${toString port.port}/' '${path}';
      '';
      streamConfig = ''
        proxy_redirect off;
        proxy_buffering off;
        set $args "";
      '';
      # TODO: accept-encoding to nothing so the response isn't compressed?
      subFilterConfig = path: ''
        sub_filter_once off;
        ${mkSubFilter motion.ports.stream "/"}
        ${mkSubFilter motion.ports.default path}
      '';
      mkStreamLocation = upstreamName: cam: {
        "~ ^/${toString cam}/(stream|motion|substream|current|source|status\\.json)$" = {
          proxy = {
            enable = true;
            upstream = mkDefault "${upstreamName}'stream";
            path = "";
          };
          extraConfig = streamConfig;
        };
      };
      streamLocations =
        map (mkStreamLocation upstreamNamePrinter) printerCams
        ++ map (mkStreamLocation upstreamNameKitchen) kitchenCams;
      locations =
        {
          "/" = {
            return = "302 /kitchen/";
          };
          "/kitchen" = {
            proxy = {
              enable = true;
              upstream = mkDefault upstreamNameKitchen;
              path = "/";
            };
            extraConfig = subFilterConfig "/kitchen/";
          };
          "/printer" = {
            proxy = {
              enable = true;
              upstream = mkDefault upstreamNamePrinter;
              path = "/";
            };
            extraConfig = subFilterConfig "/printer/";
          };
          "~ ^/(stream|motion|substream|current|source|cameras\\.json|status\\.json)$" = {
            proxy = {
              enable = true;
              upstream = mkDefault "${upstreamNameKitchen}'stream";
              path = "";
            };
            extraConfig = streamConfig;
          };
        }
        // mergeAttrsList streamLocations;
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
            ${
              if location ? proxy
              then "proxy"
              else null
            } =
              location.proxy
              // (mapDefaults {
                inherit (nginx.virtualHosts.kitchencam.locations.${name}.proxy) upstream path;
              });
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
