{lib, ...}: let
  inherit (lib.options) mkOption;
in {
  options.services.prowlarr = with lib.types; {
    port = mkOption {
      type = port;
      default = 9696;
      readOnly = true;
    };
  };
}
