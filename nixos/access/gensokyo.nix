{
  config,
  lib,
  pkgs,
  ...
}: {
  services.nginx.virtualHosts.${config.networking.domain} = {
    locations."/" = {
      root = pkgs.gensokyoZone;
    };
  };
}
