{
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  networking = {
    access.global.enable = mkDefault true;
    tempAddresses = mkDefault "disabled";
  };
}
