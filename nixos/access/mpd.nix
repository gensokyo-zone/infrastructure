{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge mkDefault;
  name.shortServer = mkDefault "radio";
  upstreamName = "radio'access";
  upstreamHigh = "${upstreamName}'high";
  upstreamLow = "${upstreamName}'low";
  upstreamMediatomb = "${upstreamName}'mediatomb";
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
      ${upstreamMediatomb} = {
        servers.service = {
          accessService = {
            name = "mediatomb";
            port = "default";
            getAddressFor = mkDefault "getAddress4For";
            network = "local";
          };
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
            #rewrite ^.*$ /high last;
            return 404;
          '';
        };
      };
      locations'local = let
        mediatomb.proxy = {
          enable = true;
          upstream = mkDefault upstreamMediatomb;
          headers.set = let
            localAddr = config.services.nginx.upstreams'.${upstreamMediatomb}.servers.service.server;
          in {
            Host = "${localAddr}";
            X-Forwarded-Host = "${localAddr}";
          };
        };
      in {
        "/mediatomb/" = mkMerge [
          mediatomb
          {
            proxy.path = "/";
          }
        ];
        "/media/" = mediatomb;
        "/interface" = mediatomb;
      };
    in {
      mpd = {
        inherit name locations;
        proxy.upstream = mkDefault upstreamName;
      };
      mpd'local = {
        inherit name;
        locations = mkMerge [ locations locations'local ];
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
