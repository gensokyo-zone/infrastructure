{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (config) kyuuto;
  inherit (config.services.nfs.export) flagSets;
  nfsRoot = {
    __toString = _: config.services.nfs.export.root.path;
    transfer = "${nfsRoot}/kyuuto/transfer";
    media = "${nfsRoot}/kyuuto/media";
    data = "${nfsRoot}/kyuuto/data";
    systems = "${nfsRoot}/kyuuto/systems";
    gengetsu = "${nfsRoot.systems}/gengetsu";
    mugetsu = "${nfsRoot.systems}/mugetsu";
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
        "${nfsRoot.gengetsu}/root" = {
          flags = flagSets.common ++ ["fsid=162"] ++ ["async"];
          clients = {
            gengetsu = {
              machine = flagSets.gengetsuClients;
              flags = flagSets.metal;
            };
          };
        };
        "${nfsRoot.gengetsu}/boot" = {
          flags = flagSets.common ++ ["fsid=163"] ++ ["async"];
          clients = {
            gengetsu = {
              machine = flagSets.gengetsuClients;
              flags = flagSets.metal;
            };
          };
        };
        "${nfsRoot.mugetsu}/root" = {
          flags = flagSets.common ++ ["fsid=170"] ++ ["async"];
          clients = {
            mugetsu = {
              machine = flagSets.mugetsuClients;
              flags = flagSets.metal;
            };
          };
        };
        "${nfsRoot.mugetsu}/boot" = {
          flags = flagSets.common ++ ["fsid=171"] ++ ["async"];
          clients = {
            mugetsu = {
              machine = flagSets.mugetsuClients;
              flags = flagSets.metal;
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
      {
        inherit type options wantedBy before;
        what = "${kyuuto.dataDir}/systems/gengetsu/fs/root";
        where = "${nfsRoot.gengetsu}/root";
      }
      {
        inherit type options wantedBy before;
        what = "${kyuuto.dataDir}/systems/gengetsu/fs/boot";
        where = "${nfsRoot.gengetsu}/boot";
      }
      {
        inherit type options wantedBy before;
        what = "${kyuuto.dataDir}/systems/mugetsu/fs/root";
        where = "${nfsRoot.mugetsu}/root";
      }
      {
        inherit type options wantedBy before;
        what = "${kyuuto.dataDir}/systems/mugetsu/fs/boot";
        where = "${nfsRoot.mugetsu}/boot";
      }
    ];
}
