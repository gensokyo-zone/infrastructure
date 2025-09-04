{
  lib,
  modulesPath,
  meta,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.hw.headless
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  environment.variables = {
    # nix default is way too big
    GC_INITIAL_HEAP_SIZE = mkDefault "8M";
  };
  # XXX: this might be okay if the nix daemon's tmp is overridden
  # (but still avoid since containers are usually low on provisioned memory)
  boot.tmp.useTmpfs = mkDefault false;
}
