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
      inherit (network) internal;
      inherit (network.interfaces) net0;
      mapAddress6 = prefix: interface:
        if interface.address6 == "dhcp" then null
        else if interface.address6 == "auto" then "${prefix}${interface.slaac.postfix}"
        else mapNullable (removeSuffix "/64") interface.address6;
      mapAddress4 = interface:
        if elem interface.address4 [ "dhcp" "auto" ] then null
        else mapNullable (removeSuffix "/24") interface.address4;
    in {
      int = if internal.interface != null then {
        inherit (internal.interface) macAddress;
        address6 = mapAddress6 "fd0c::" internal.interface;
        address4 = mapAddress4 internal.interface;
      } else null;
      local = if network.interfaces.net0.bridge or null == "vmbr0" then {
        inherit (net0) macAddress;
        address6 = mapAddress6 "fd0a::" net0;
        address4 = mapAddress4 net0;
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
