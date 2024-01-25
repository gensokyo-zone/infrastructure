{
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
in {
  options.services.readarr = with lib.types; {
    port = mkOption {
      type = port;
      default = 8787;
      readOnly = true;
    };
  };
}
