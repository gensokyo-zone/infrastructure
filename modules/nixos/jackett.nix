{lib, ...}: let
  inherit (lib.options) mkOption;
in {
  options.services.jackett = with lib.types; {
    port = mkOption {
      type = port;
      default = 9117;
      readOnly = true;
    };
  };
}
