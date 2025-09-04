{
  lib,
  meta,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.ct.proxmox
    nixos.avahi
  ];

  services.kanidm.serverSettings.db_fs_type = mkDefault "zfs";
}
