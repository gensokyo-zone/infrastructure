{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkMerge mkIf mkBefore mkForce mkOptionDefault;
  inherit (lib.lists) optional;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) toList;
  inherit (lib.strings) optionalString concatStringsSep concatMapStringsSep;
  cfg = config.services.nfs;
  clientEnabled = config.boot.supportedFilesystems.nfs or config.boot.supportedFilesystems.nfs4 or false;
  enabled = cfg.server.enable || clientEnabled;
  openPorts = [
    (mkIf cfg.server.enable 2049)
    (mkIf config.services.rpcbind.enable 111)
    (mkIf (cfg.server.statdPort != null) cfg.server.statdPort)
    (mkIf (cfg.server.lockdPort != null) cfg.server.lockdPort)
    (mkIf (cfg.server.mountdPort != null) cfg.server.mountdPort)
  ];
  concatFlags = concatStringsSep ",";
  clientModule = { config, name, ... }: {
    options = with lib.types; {
      machine = mkOption {
        type = oneOf [ str (listOf str) ];
        default = name;
        example = "*";
      };
      flags = mkOption {
        type = listOf str;
        default = [ ];
      };
      entry = mkOption {
        type = str;
      };
    };
    config = {
      entry = let
        flags = optionalString (config.flags != [ ]) "(${concatFlags config.flags})";
        machines = toList config.machine;
      in mkOptionDefault (concatMapStringsSep " " (machine: machine + flags) machines);
    };
  };
  exportModule = { config, name, ... }: {
    options = with lib.types; {
      path = mkOption {
        type = path;
        default = name;
      };
      flags = mkOption {
        type = listOf str;
      };
      clients = mkOption {
        type = attrsOf (submodule clientModule);
      };
      fileLine = mkOption {
        type = str;
      };
    };
    config = {
      flags = mkOptionDefault (cfg.export.flagSets.common or [ ]);
      fileLine = let
        parts = [ config.path ]
          ++ optional (config.flags != [ ]) "-${concatFlags config.flags}"
          ++ mapAttrsToList (_: client: client.entry) config.clients;
      in mkOptionDefault (concatStringsSep " " parts);
    };
  };
in {
  options.services.nfs = with lib.types; {
    export = {
      flagSets = mkOption {
        type = lazyAttrsOf (listOf str);
        default = {
          common = [ "no_subtree_check" ];
        };
      };
      root = mkOption {
        type = nullOr (submodule [
          exportModule
          ({ ... }: {
            flags = mkMerge [
              (cfg.export.flagSets.common or [ ])
            ];
          })
        ]);
        default = null;
      };
      paths = mkOption {
        type = attrsOf (submodule exportModule);
        default = { };
      };
    };
  };
  config = {
    services.nfs = {
      server.exports = mkMerge (
        optional (cfg.export.root != null) (mkBefore cfg.export.root.fileLine)
        ++ mapAttrsToList (_: export: export.fileLine) cfg.export.paths
      );
    };
    networking.firewall.interfaces.local = mkIf enabled {
      allowedTCPPorts = openPorts;
      allowedUDPPorts = openPorts;
    };
    systemd.services = {
      auth-rpcgss-module = mkIf (enabled && !config.boot.modprobeConfig.enable) {
        serviceConfig.ExecStart = mkForce [
          ""
          "${pkgs.coreutils}/bin/true"
        ];
      };
      rpc-svcgssd = mkIf enabled {
        enable = mkIf (!cfg.server.enable) false;
        wantedBy = mkIf (cfg.server.enable && (config.security.krb5.enable || config.security.ipa.enable)) [
          "nfs-server.service"
        ];
      };
      nfs-mountd = mkIf cfg.server.enable {
        environment.LD_LIBRARY_PATH = config.system.nssModules.path;
      };
    };
    systemd.mounts = mkIf (cfg.server.enable && cfg.export.root != null) [
      rec {
        type = "tmpfs";
        options = "rw,size=256k";
        what = "none";
        where = cfg.export.root.path;
        requiredBy = [
          "nfs-server.service"
          "nfs-mountd.service"
        ];
        before = requiredBy;
      }
    ];
  };
}
