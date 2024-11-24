{meta, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    ./hardware-configuration.nix
    #nixos.sops
    nixos.base
  ];

  system.stateVersion = "24.05";
}
