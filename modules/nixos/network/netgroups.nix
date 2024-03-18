{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkAfter mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.strings) concatStringsSep;
  inherit (config.system) nssDatabases;
  inherit (config) networking;
  netgroupMemberModule = { config, name, ... }: {
    options = with lib.types; {
      hostname = mkOption {
        type = str;
        default = name;
      };
      user = mkOption {
        type = either (enum [ null "-" ]) str;
        default = "-";
      };
      domain = mkOption {
        type = str;
        default = networking.domain;
        description = "NIS domain";
      };
      triple = mkOption {
        type = str;
      };
    };
    config = {
      triple = mkOptionDefault "(${config.hostname},${toString config.user},${config.domain})";
    };
  };
  netgroupModule = { config, name, ... }: {
    options = with lib.types; {
      name = mkOption {
        type = str;
        default = name;
      };
      members = mkOption {
        type = attrsOf (submodule netgroupMemberModule);
        default = { };
      };
      fileLine = mkOption {
        type = str;
      };
    };
    config = {
      fileLine = mkOptionDefault (concatStringsSep " " ([ config.name ] ++ mapAttrsToList (_: member: member.triple) config.members));
    };
  };
in {
  options = with lib.types; {
    system.nssDatabases = {
      netgroup = mkOption {
        type = listOf str;
      };
    };
    networking = {
      netgroups = mkOption {
        type = attrsOf (submodule netgroupModule);
        default = { };
      };
      extraNetgroups = mkOption {
        type = lines;
        default = "";
      };
    };
  };
  config = {
    system.nssDatabases = {
      netgroup = mkMerge [
        (mkBefore [ "files" ])
        (mkAfter [ "nis" ])
        (mkIf config.services.sssd.enable [ "sss" ])
      ];
    };
    environment.etc."nssswitch.conf".text = mkIf (nssDatabases.netgroup != [ ]) (mkAfter ''
      netgroup: ${concatStringsSep " " nssDatabases.netgroup}
    '');
    environment.etc."netgroup" = mkIf (networking.netgroups != { } || networking.extraNetgroups != "") {
      text = mkMerge (
        mapAttrsToList (_: ng: ng.fileLine) networking.netgroups
        ++ [ networking.extraNetgroups ]
      );
    };
  };
}
