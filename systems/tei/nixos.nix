{
  meta,
  lib,
  ...
}: {
  imports = with meta; [
    nixos.reisen-ct
    nixos.sops
    nixos.tailscale
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "21.05";
}
