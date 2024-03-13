{lib, ...}: let
  inherit (lib.options) mkOption;
in {
  options.services.sonarr = with lib.types; {
    port = mkOption {
      type = port;
      default = 8989;
      readOnly = true;
    };
  };
}
