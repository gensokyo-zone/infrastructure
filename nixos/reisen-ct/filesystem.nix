{lib, ...}: let
  inherit (lib) mkDefault;
in {
  services.kanidm.serverSettings.db_fs_type = mkDefault "zfs";
  # work around a filesystem issue when migrating an unprivileged container to privileged
  boot.postBootCommands = ''
    if [[ $(stat -c '%u' /) != 0 ]]; then
      chown 0:0 / /*
    fi
  '';
}
