{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  services.steam.accountSwitch = {
    enable = mkDefault true;
  };
}
