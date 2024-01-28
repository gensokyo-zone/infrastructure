{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  services.nginx.virtualHosts.${config.networking.domain} = {
    locations."/" = {
      root = inputs.website.packages.${pkgs.system}.gensokyoZone;
    };
  };
}
