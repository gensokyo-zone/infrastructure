{
  meta,
  ...
}: {
  imports = let
    inherit (meta) nixos;
  in [
    ./hardware-configuration.nix
    #nixos.sops
    nixos.base
    nixos.netboot.kyuuto
  ];

  system.stateVersion = "24.11";
}
