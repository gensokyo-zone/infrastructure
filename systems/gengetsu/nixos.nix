{
  config,
  gensokyo-zone,
  meta,
  ...
}: let
  inherit (gensokyo-zone.lib) domain;
in {
  imports = let
    inherit (meta) nixos;
  in [
    ./hardware-configuration.nix
    #nixos.sops
    nixos.base
  ];

  fileSystems = let
    inherit (config.gensokyo-zone) netboot;
    #nfsHost = netboot.nfs.host;
    nfsHost = "nfs.local.${domain}";
  in {
    "/mnt/goliath/boot" = {
      device = "${nfsHost}:/srv/fs/kyuuto/systems/goliath/boot";
      options = ["sec=sys" "nofail"] ++ netboot.nfs.flags;
      fsType = "nfs";
    };
  };

  system.stateVersion = "24.05";
}
