{
  meta,
  lib,
  ...
}: {
  imports = with meta; [
    nixos.reisen-ct
    nixos.sops
    nixos.tailscale
    nixos.cloudflared
    nixos.postgres
    nixos.nginx
    nixos.access.gensokyo
    ./cloudflared.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
