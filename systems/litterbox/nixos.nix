{meta, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.tailscale
    nixos.syncthing-kat
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
