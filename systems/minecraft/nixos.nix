{
  meta,
  config,
  ...
}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.reisen-ct
    nixos.tailscale
    nixos.kyuuto.mount
    nixos.minecraft.java
  ];

  environment.systemPackages = [
    config.services.minecraft-java-server.jre.package
  ];

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets.tailscale-key.key = "tailscale-key";
  };

  system.stateVersion = "23.11";
}
