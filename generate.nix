{
  inputs,
  tree,
}: let
  nixlib = inputs.nixpkgs.lib;
  inherit (nixlib.attrsets) mapAttrs filterAttrs mapAttrsToList;
  inherit (nixlib.lists) elem sortOn;
  inherit (nixlib.strings) removeSuffix;
  inherit (nixlib.trivial) mapNullable warn;
  inherit (inputs.self.lib.lib) userIs;
  templateSystem = inputs.self.nixosConfigurations.reimu;
  templateUsers = filterAttrs (_: userIs "peeps") templateSystem.config.users.users;
  mkNodeUsers = users: let
    nodeUsers = mapAttrsToList (_: mkNodeUser) templateUsers;
  in
    sortOn (user: user.uid) nodeUsers;
  mkNodeUser = user: {
    inherit (user) name uid;
    authorizedKeys = user.openssh.authorizedKeys.keys;
  };
  nodeSystems = let
    matchesNode = nodeName: system: system.config.proxmox.enabled && system.config.proxmox.node.name == nodeName;
  in nodeName: filterAttrs (_: matchesNode nodeName) inputs.self.lib.systems;
  mkNodeSystem = system: {
    network = let
      inherit (system.config.proxmox) network;
      inherit (network) internal local;
    in {
      int = if internal.interface != null then {
        inherit (internal.interface) macAddress;
        address4 = removeSuffix "/24" internal.interface.address4;
        address6 = removeSuffix "/64" internal.interface.address6;
      } else null;
      local = if local.interface != null then {
        inherit (local.interface) macAddress;
        address4 = mapNullable (removeSuffix "/24") local.interface.local.address4;
        address6 = mapNullable (removeSuffix "/64") local.interface.local.address6;
      } else null;
      tail = warn "TODO: generate network.tail" null;
    };
  };
  mkNodeSystems = systems: mapAttrs (_: mkNodeSystem) systems;
  mkNode = {name}: {
    users = mkNodeUsers templateUsers;
    systems = mkNodeSystems (nodeSystems name);
  };
in {
  reisen = mkNode {name = "reisen";};
}
