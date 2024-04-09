{meta, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.nixbld
    nixos.tailscale
    nixos.github-runner.zone
  ];

  nix.gc = {
    dates = "monthly";
    options = "--delete-older-than 30d";
  };

  services.github-runner-zone = {
    count = 16;
    networkNamespace.name = "ns1";
  };

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
