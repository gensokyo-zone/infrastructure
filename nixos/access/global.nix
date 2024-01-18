{
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  networking = {
    tempAddresses = mkDefault "disabled";
  };
}
