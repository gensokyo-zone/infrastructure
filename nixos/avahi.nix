{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  services.avahi = {
    enable = mkDefault true;
    ipv6 = mkDefault config.networking.enableIPv6;
    publish = {
      enable = mkDefault true;
      domain = mkDefault true;
      addresses = mkDefault true;
      userServices = mkDefault true;
    };
    wideArea = mkDefault false;
  };
}
