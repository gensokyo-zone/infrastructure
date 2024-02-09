{
  inputs,
  tree,
}: let
  nixlib = inputs.nixpkgs.lib;
  inherit (nixlib.attrsets) filterAttrs mapAttrsToList;
  inherit (nixlib.lists) sortOn;
  inherit (inputs.self.lib.lib) userIs;
  templateSystem = inputs.self.nixosConfigurations.reimu;
  templateUsers = filterAttrs (_: userIs "peeps") templateSystem.config.users.users;
  mkNodeUsers = users: let
    nodeUsers = mapAttrsToList (_: mkNodeUser) templateUsers;
  in sortOn (user: user.uid) nodeUsers;
  mkNodeUser = user: {
    inherit (user) name uid;
    authorizedKeys = user.openssh.authorizedKeys.keys;
  };
  mkNode = {
    name,
  }: {
    users = mkNodeUsers templateUsers;
  };
in {
  reisen = mkNode { name = "reisen"; };
}
