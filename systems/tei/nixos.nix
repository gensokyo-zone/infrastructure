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
    nixos.nginx
    nixos.access.gensokyo
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
