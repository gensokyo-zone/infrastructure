{meta, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.ct.meiling
    nixos.tailscale
    nixos.syncthing-kat
  ];

  services = {
    prometheus.exporters.node.enable = false;
    promtail.enable = false;
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets.tailscale-key.key = "tailscale-key";
  };

  system.stateVersion = "23.11";
}
