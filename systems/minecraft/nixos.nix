{meta, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.reisen-ct
    nixos.tailscale
  ];

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets.tailscale-key.key = "tailscale-key";
  };

  system.stateVersion = "23.11";
}
