{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.attrsets) mapAttrs' mapAttrsToList nameValuePair;
  inherit (lib.lists) concatLists;
  inherit (config) kyuuto;
  inherit (config.services.nfs.export) flagSets;
  nfsRoot = {
    __toString = _: config.services.nfs.export.root.path;
    transfer = "${nfsRoot}/kyuuto/transfer";
    media = "${nfsRoot}/kyuuto/media";
    data = "${nfsRoot}/kyuuto/data";
    systems = "${nfsRoot}/kyuuto/systems";
  };
  mkSystemExport = {
    name,
    fsid,
    machine,
    flags ? ["async"],
    machineFlags ? flagSets.metal,
  }: {
    flags = flagSets.common ++ ["fsid=${toString fsid}"] ++ flags;
    clients = {
      ${name} = {
        inherit machine;
        flags = machineFlags;
      };
      admin = {
        machine = flagSets.adminClients;
        flags = machineFlags;
      };
    };
  };
  mkSystemExports = name: {
    machine,
    fileSystems,
  }: let
    systemRoot = "${nfsRoot.systems}/${name}";
    mapSystemExport = fsName: fs:
      nameValuePair "${systemRoot}/${fsName}" (mkSystemExport ({
          inherit name machine;
        }
        // fs));
  in
    mapAttrs' mapSystemExport fileSystems;
  exportedSystems = {
    gengetsu = {
      machine = flagSets.gengetsuClients;
      fileSystems = {
        root.fsid = 162;
        boot.fsid = 163;
      };
    };
    mugetsu = {
      machine = flagSets.mugetsuClients;
      fileSystems = {
        root.fsid = 170;
        boot.fsid = 171;
      };
    };
    goliath = {
      machine = flagSets.goliathClients;
      fileSystems = {
        root.fsid = 172;
        boot.fsid = 173;
      };
    };
  };
in {
  services.nfs = {
    export = let
      exportPaths = {
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
      systemPaths = mkMerge (mapAttrsToList mkSystemExports exportedSystems);
    in {
      paths = mkMerge [
        exportPaths
        systemPaths
      ];
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
    mkMount = {
      what,
      where,
      ...
    } @ args:
      {
        inherit type options wantedBy before;
      }
      // args;
    mkSystemMount = {
      name,
      fsName,
    }: let
      systemRoot = "${nfsRoot.systems}/${name}";
    in
      mkMount {
        what = "${kyuuto.dataDir}/systems/${name}/fs/${fsName}";
        where = "${systemRoot}/${fsName}";
      };
    mapSystemMounts = name: {fileSystems, ...}: let
      mapFileSystem = fsName: fs: mkSystemMount {inherit name fsName;};
    in
      mapAttrsToList mapFileSystem fileSystems;
    systemMounts = let
      systemMounts = mapAttrsToList mapSystemMounts exportedSystems;
    in
      concatLists systemMounts;
    exportMounts = map mkMount [
      {
        what = kyuuto.mountDir;
        where = nfsRoot.media;
      }
      {
        what = kyuuto.dataDir;
        where = nfsRoot.data;
      }
      {
        what = kyuuto.transferDir;
        where = nfsRoot.transfer;
      }
    ];
    pathMounts = mkMerge [
      exportMounts
      systemMounts
    ];
  in
    mkIf config.services.nfs.server.enable pathMounts;
}
