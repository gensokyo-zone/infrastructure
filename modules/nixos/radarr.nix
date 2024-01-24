{
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
in {
  options.services.radarr = with lib.types; {
    port = mkOption {
      type = port;
      default = 7878;
      readOnly = true;
    };
  };
}
