
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
    mapPerm = perm: map (addr: "${addr}(${perm})");
    toPerms = concatStringsSep " ";
    localAddrs = cidrForNetwork.loopback.all ++ cidrForNetwork.local.all;
    tailAddrs = optionals config.services.tailscale.enable cidrForNetwork.tail.all;
    allAddrs = localAddrs ++ tailAddrs;
    kyuutoPerms =
      mapPerm "ro" localAddrs
      ++ mapPerm "rw" tailAddrs;
    transferPerms = mapPerm "rw" allAddrs;
  in ''
    ${kyuuto.mountDir} ${toPerms kyuutoPerms}
    ${kyuuto.transferDir} ${toPerms transferPerms}
  '';
}
