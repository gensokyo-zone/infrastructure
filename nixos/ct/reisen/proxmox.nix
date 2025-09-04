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
  ];

  services.kanidm.serverSettings.db_fs_type = mkDefault "zfs";
}
