{
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  services.bazarr = {
    enable = mkDefault true;
    listenPort = mkDefault 6767;
  };
}
