{
  config,
  lib,
  ...
}: let
  inherit (lib.lists) optionals;
  inherit (lib.strings) concatStringsSep;
  inherit (config.networking.access) cidrForNetwork;
  inherit (config) kyuuto;
in {
  services.nfs.server.exports = let
    mapPerm = perm: map (addr: "${addr}(${concatStringsSep "," perm})");
    toPerms = concatStringsSep " ";
    localAddrs = cidrForNetwork.loopback.all ++ cidrForNetwork.local.all;
    tailAddrs = optionals config.services.tailscale.enable cidrForNetwork.tail.all;
    allAddrs = localAddrs ++ tailAddrs;
    globalAddrs = [
      "@peeps"
    ];
    common = [
      "no_subtree_check"
    ];
    sec = [
      "sec=${concatStringsSep ":" [ "krb5i" "krb5" "krb5p" ]}"
      # TODO: no_root_squash..?
    ];
    anon = [
      "sec=sys"
      "all_squash"
      "anonuid=${toString config.users.users.guest.uid}"
      "anongid=${toString config.users.groups.${config.users.users.guest.group}.gid}"
    ];
    # TODO: this can be simplified by specifying `sec=` multiple times, with restrictive options following sec=sys,all_squash,ro,etc
    kyuutoOpts = common;
    kyuutoPerms =
      mapPerm (kyuutoOpts ++ [ "rw" ] ++ sec) globalAddrs
      ++ mapPerm (kyuutoOpts ++ [ "ro" ] ++ anon) localAddrs
      # XXX: remove me once kerberos is set up!
      ++ mapPerm (kyuutoOpts ++ [ "rw" "sec=sys" ]) tailAddrs
    ;
    transferOpts = common ++ [ "rw" "async" ];
    transferPerms =
      mapPerm (transferOpts ++ sec) globalAddrs
      ++ mapPerm (transferOpts ++ anon) allAddrs
    ;
  in ''
    ${kyuuto.mountDir} ${toPerms kyuutoPerms}
    ${kyuuto.transferDir} ${toPerms transferPerms}
  '';
}
