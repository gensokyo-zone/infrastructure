{
  lib,
  ...
}: let
  inherit (lib) mkDefault;
in {
  services.resolved.enable = true;
  services.avahi = {
    enable = mkDefault true;
    publish = {
      enable = mkDefault true;
      domain = mkDefault true;
      addresses = mkDefault true;
      userServices = mkDefault true;
    };
    wideArea = mkDefault false;
  };
}
