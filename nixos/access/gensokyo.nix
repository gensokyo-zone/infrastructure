{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  services.nginx.virtualHosts.${config.networking.domain} = {
    locations."/" = {
      root = pkgs.gensokyoZone;
    };
  };
}
