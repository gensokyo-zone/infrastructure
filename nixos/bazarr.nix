{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  services.bazarr = {
    enable = mkDefault true;
    listenPort = mkDefault 6767;
  };
  users.users.bazarr.extraGroups = ["kyuuto"];
}
