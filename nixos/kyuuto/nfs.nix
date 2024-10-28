{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.lists) optionals;
  inherit (lib.strings) concatStringsSep;
  inherit (config.networking.access) cidrForNetwork;
  inherit (config) kyuuto;
  inherit (config.services.nfs.export) flagSets;
  nfsRoot = {
    __toString = _: config.services.nfs.export.root.path;
    transfer = "${nfsRoot}/kyuuto/transfer";
    media = "${nfsRoot}/kyuuto/media";
    data = "${nfsRoot}/kyuuto/data";
  };
in {
  services.nfs = {
    export = {
      paths = {
        ${nfsRoot.media} = {
          flags = flagSets.common ++ ["fsid=128"] ++ flagSets.secip ++ ["rw"] ++ flagSets.anon_ro;
          clients = {
            local = {
              machine = flagSets.allClients;
              flags = flagSets.seclocal ++ ["rw" "no_all_squash"];
            };
          };
        };
        ${nfsRoot.data} = {
          flags = flagSets.common ++ ["fsid=130"] ++ flagSets.secip ++ ["rw"] ++ flagSets.anon_ro;
          clients = {
            local = {
              machine = flagSets.allClients;
              flags = flagSets.seclocal ++ ["rw" "no_all_squash"];
            };
          };
        };
        ${nfsRoot.transfer} = {
          flags = flagSets.common ++ ["fsid=129"] ++ ["rw" "async"];
          clients = {
            local = {
              machine = flagSets.allClients;
              flags = flagSets.secanon;
            };
          };
        };
      };
    };
  };
  systemd.mounts = let
    type = "none";
    options = "bind";
    wantedBy = [
      "nfs-server.service"
      "nfs-mountd.service"
    ];
    before = wantedBy;
  in
    mkIf config.services.nfs.server.enable [
      {
        inherit type options wantedBy before;
        what = kyuuto.mountDir;
        where = nfsRoot.media;
      }
      {
        inherit type options wantedBy before;
        what = kyuuto.dataDir;
        where = nfsRoot.data;
      }
      {
        inherit type options wantedBy before;
        what = kyuuto.transferDir;
        where = nfsRoot.transfer;
      }
    ];
}
