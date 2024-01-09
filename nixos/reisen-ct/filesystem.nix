{
  lib,
  ...
}: let
  inherit (lib) mkDefault;
in {
  services.kanidm.serverSettings.db_fs_type = mkDefault "zfs";
}
