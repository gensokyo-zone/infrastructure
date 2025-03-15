{
  meta,
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
    nixos.base
    nixos.reisen-ct
    nixos.nixbld
    #nixos.cross.aarch64 # XXX: binfmt_misc namespaces not yet supported :<
    nixos.tailscale
    nixos.github-runner.zone
    nixos.minecraft.bedrock
  ];

  nix.gc = {
    dates = "monthly";
    options = "--delete-older-than 30d";
  };

  services.github-runner-zone = {
    enable = mkIf isOffline false;
    count = 32;
    networkNamespace.name = "ns1";
  };

  boot.tmp.tmpfsSize = "32G";

  networking.namespaces.ns1 = {
    dhcpcd.enable = true;
    nftables = {
      enable = true;
      rejectLocaladdrs = true;
      serviceSettings = rec {
        wants = ["localaddrs.service"];
        after = wants;
      };
    };
    interfaces.eth1 = {};
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";

  systemd.services.minecraft-bedrock-server = mkIf isOffline {
    wantedBy = mkForce [];
  };
}
