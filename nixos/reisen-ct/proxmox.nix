{
  systemConfig,
  gensokyo-zone,
  lib,
  modulesPath,
  meta,
  ...
}: let
  inherit (gensokyo-zone.lib) unmerged;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (systemConfig) proxmox;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.hw.headless
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  environment.variables = {
    # nix default is way too big
    GC_INITIAL_HEAP_SIZE = mkDefault "8M";
  };
  # XXX: this might be okay if the nix daemon's tmp is overridden
  # (but still avoid since containers are usually low on provisioned memory)
  boot.tmp.useTmpfs = mkDefault false;

  proxmoxLXC.privileged = mkIf (proxmox.container.enable && proxmox.container.privileged) true;

  systemd.network = mkIf proxmox.enabled (mkMerge (mapAttrsToList (_: interface:
    mkIf (interface.enable && interface.networkd.enable) {
      networks.${interface.networkd.name} = unmerged.mergeAttrs interface.networkd.networkSettings;
    })
  proxmox.network.interfaces));

  networking.firewall.interfaces = let
    inherit (proxmox.network) internal;
    intConditions = ["iifname ${internal.interface.name}"];
  in
    mkIf (internal.interface != null) {
      lan.nftables.conditions = intConditions;
      local.nftables.conditions = intConditions;
    };
}
