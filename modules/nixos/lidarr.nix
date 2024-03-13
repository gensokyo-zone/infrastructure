{lib, ...}: let
  inherit (lib.options) mkOption;
in {
  options.services.lidarr = with lib.types; {
    port = mkOption {
      type = port;
      default = 8686;
      readOnly = true;
    };
  };
}
