{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
  name.shortServer = mkDefault "radio";
  upstreamName = "radio'access";
  upstreamHigh = "${upstreamName}'high";
  upstreamLow = "${upstreamName}'low";
in {
  config.services.nginx = {
    upstreams' = {
      ${upstreamHigh} = {
        servers.service = {
          #accessService.system = "shanghai";
          addr = "shanghai.local.cutie.moe";
          port = 32101;
        };
      };
      ${upstreamLow} = {
        servers.service = {
          #accessService.system = "shanghai";
          addr = "shanghai.local.cutie.moe";
          port = 32102;
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "mpd";
      extraConfig = ''
        proxy_buffering off;
      '';
      locations = {
        "/low" = {
          inherit extraConfig;
          proxy = {
            enable = true;
            upstream = mkDefault upstreamLow;
          };
        };
        "/high" = {
          inherit extraConfig;
          proxy = {
            enable = true;
            upstream = mkDefault upstreamHigh;
          };
        };
        "/" = {
          extraConfig = ''
            rewrite ^.*$ /high last;
            return 404;
          '';
        };
      };
    in {
      mpd = {
        inherit name locations;
        proxy.upstream = mkDefault upstreamName;
      };
      mpd'local = {
        inherit name locations;
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
}
