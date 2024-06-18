{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
in {
  config.exports.services.nfandroidtv = {config, ...}: {
    displayName = mkAlmostOptionDefault "Notifications for Android TV";
    ports.default = {
      port = mkAlmostOptionDefault 7676;
      protocol = "http";
      #status.enable = mkAlmostOptionDefault true;
    };
  };
}
