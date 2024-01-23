{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  services.nginx.virtualHosts.${config.networking.domain} = {
    default = mkDefault true;
    locations."/" = {
      root = pkgs.gensokyoZone;
    };
  };
}
