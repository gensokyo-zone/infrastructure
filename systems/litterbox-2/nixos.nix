{meta, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.meiling-ct
    nixos.tailscale
    nixos.syncthing-kat
  ];

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets.tailscale-key.key = "tailscale-key";
  };

  system.stateVersion = "23.11";
}
