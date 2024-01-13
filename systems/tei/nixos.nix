{
  meta,
  lib,
  ...
}: {
  imports = with meta; [
    nixos.reisen-ct
    nixos.sops
    nixos.tailscale
    nixos.postgres
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
