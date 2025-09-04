{
  config,
  systemConfig,
  gensokyo-zone,
  lib,
  meta,
  ...
}: let
  inherit (gensokyo-zone.lib) unmerged;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (systemConfig) proxmox;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.hw.proxmox
  ];

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

  image.baseName = "${systemConfig.name}-${config.system.nixos.label}-proxmox";
}
