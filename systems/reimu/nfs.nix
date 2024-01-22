{
  config,
  lib,
  ...
}: let
  kyuuto = "/mnt/kyuuto-media";
  kyuuto-transfer = kyuuto + "/transfer";
  inherit (lib.lists) optionals;
  inherit (lib.strings) concatStringsSep;
  inherit (config.networking.access) cidrForNetwork;
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
    ${kyuuto} ${toPerms kyuutoPerms}
    ${kyuuto-transfer} ${toPerms transferPerms}
  '';

  services.samba.shares = {
    kyuuto-transfer = {
      path = kyuuto-transfer;
      writeable = "yes";
      browseable = "yes";
      public = "yes";
      "guest only" = "yes";
      comment = "Kyuuto Media Transfer Area";
    };
    kyuuto-access = {
      path = kyuuto;
      writeable = false;
      browseable = "yes";
      public = "yes";
      comment = "Kyuuto Media Access";
    };
    kyuuto-media = {
      path = kyuuto;
      writeable = "yes";
      browseable = "yes";
      public = "no";
      comment = "Kyuuto Media";
    };
  };
}
