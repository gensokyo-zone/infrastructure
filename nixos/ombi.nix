{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  services.ombi = {
    enable = mkDefault true;
    port = mkDefault 5000;
  };
}
