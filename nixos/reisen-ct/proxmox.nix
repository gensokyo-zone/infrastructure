{
  lib,
  modulesPath,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  services.getty.autologinUser = mkDefault "root";
  documentation.enable = mkDefault false;

  environment.variables = {
    # nix default is way too big
    GC_INITIAL_HEAP_SIZE = mkDefault "8M";
  };
}
