{meta, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.nixbld
    #nixos.cross.aarch64
    nixos.tailscale
    nixos.github-runner.zone
    nixos.minecraft.bedrock
  ];

  nix.gc = {
    dates = "monthly";
    options = "--delete-older-than 30d";
  };

  services.github-runner-zone = {
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
}
