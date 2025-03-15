{
  meta,
  config,
  systemConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkForce;
  isOffline = !systemConfig.access.online.available;
in {
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

  systemd = mkIf isOffline {
    services.minecraft-java-server.wantedBy = mkForce [];
    sockets.minecraft-java-server.wantedBy = mkForce [];
  };
}
