{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  boot = {
    initrd.systemd.emergencyAccess = mkDefault true;
    consoleLogLevel = mkDefault 5;
  };
  services.getty.autologinUser = mkDefault "root";
  documentation.enable = mkDefault false;
}
