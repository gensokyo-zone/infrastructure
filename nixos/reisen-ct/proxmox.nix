{
  config,
  system,
  gensokyo-zone,
  lib,
  modulesPath,
  ...
}: let
  inherit (gensokyo-zone.lib) unmerged coalesce;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.trivial) mapNullable;
  inherit (system) proxmox;
in {
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  services.getty.autologinUser = mkDefault "root";
  documentation.enable = mkDefault false;

  environment.variables = {
    # nix default is way too big
    GC_INITIAL_HEAP_SIZE = mkDefault "8M";
  };

  proxmoxLXC.privileged = mkIf (proxmox.container.enable && proxmox.container.privileged) true;

  systemd.network = mkIf proxmox.enabled (mkMerge (mapAttrsToList (_: interface: mkIf (interface.enable && interface.networkd.enable) {
    networks.${interface.networkd.name} = unmerged.mergeAttrs interface.networkd.networkSettings;
  }) proxmox.network.interfaces));

  networking.firewall.interfaces.lan = let
    inherit (proxmox.network) internal local;
    conditions = coalesce [
      (mapNullable (interface: [ "iifname ${interface.name}" ]) internal.interface)
      (mapNullable (interface: config.networking.interfaces.local.nftables.conditions) local.interface)
    ];
  in mkIf (conditions != null) {
    nftables = {
      inherit conditions;
    };
  };
}
