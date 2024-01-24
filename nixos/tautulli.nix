{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  services.tautulli = {
    enable = mkDefault true;
    port = mkDefault 8181;
  };
}
