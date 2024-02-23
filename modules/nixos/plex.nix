{
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
in {
  options.services.plex = with lib.types; {
    port = mkOption {
      type = port;
      default = 32400;
      readOnly = true;
    };
  };
}
