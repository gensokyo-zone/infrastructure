{
  inputs,
  tree,
}: let
  nixlib = inputs.nixpkgs.lib;
  inherit (nixlib.attrsets) attrNames mapAttrs mapAttrs' nameValuePair filterAttrs mapAttrsToList;
  inherit (nixlib.lists) sortOn;
  inherit (inputs.self.lib.lib) userIs;
  inherit (inputs.self.lib.gensokyo-zone) systems;
  templateSystem = inputs.self.nixosConfigurations.reimu.config;
  templateUsers = filterAttrs (_: userIs "peeps") templateSystem.users.users;
  mkNodeUsers = users: let
    nodeUsers = mapAttrsToList (_: mkNodeUser) templateUsers;
  in
    sortOn (user: user.uid) nodeUsers;
  mkNodeUser = user: {
    inherit (user) name uid;
    authorizedKeys = user.openssh.authorizedKeys.keys;
  };
  nodeSystems = let
    matchesNode = nodeName: system: system.proxmox.enabled && system.proxmox.node.name == nodeName;
  in
    nodeName: filterAttrs (_: matchesNode nodeName) systems;
  mkNodeSystem = system: {
    inherit (system.access) hostName;
    network = let
      inherit (system.network) networks;
    in {
      networks = {
        int =
          if networks.int.enable or false
          then {
            inherit (networks.int) macAddress address4 address6;
          }
          else null;
        local =
          if networks.local.enable or false
          then {
            inherit (networks.local) macAddress address4 address6;
          }
          else null;
        tail =
          if networks.tail.enable or false
          then {
            inherit (networks.tail) address4 address6;
            macAddress = null;
          }
          else null;
      };
    };
  };
  mkNodeSystems = systems: mapAttrs (_: mkNodeSystem) systems;
  mkExtern = system: let
    enabledFiles = filterAttrs (_: file: file.enable) system.extern.files;
  in {
    files = mapAttrs' (_: file:
      nameValuePair file.path {
        source = assert file.relativeSource != null; file.relativeSource;
        inherit (file) owner group mode;
      })
    enabledFiles;
  };
  mkNode = system: {
    users = mkNodeUsers templateUsers;
    systems = mkNodeSystems (nodeSystems system.name);
    extern = mkExtern system;
    ssh.root.authorizedKeys = {
      inherit (templateSystem.environment.etc."ssh/authorized_keys.d/root".source) text;
    };
  };
  mkNetwork = system: {
    inherit (system.access) hostName;
    networks =
      {
        int = null;
        local = null;
        tail = null;
        global = null;
      }
      // mapAttrs' (_: network:
        nameValuePair network.name {
          inherit (network) macAddress address4 address6;
        })
      system.network.networks;
  };
  mkSystem = name: system: {
    network = mkNetwork system;
  };
in {
  nodes = let
    nodes = filterAttrs (_: node: node.proxmox.node.enable) systems;
  in
    mapAttrs (_: mkNode) nodes;
  nodeNames = attrNames inputs.self.lib.generate.nodes;
  systems = mapAttrs mkSystem systems;
}
