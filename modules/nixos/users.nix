{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkMerge mkAfter mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList attrValues;
  inherit (lib.lists) filter;
  inherit (lib.strings) concatStringsSep;
  opensshMatchUsers = filter (user: user.openssh.matchBlock.enable) (attrValues config.users.users);
  toSshdCriteria = key: value: "${key} ${value}";
  userMatchBlock = user: let
    inherit (user.openssh) matchBlock;
    criteria = mapAttrsToList toSshdCriteria matchBlock.criteria;
  in mkAfter ''
    Match ${concatStringsSep " " criteria}
    ${matchBlock.settingsConfig}
  '';
  userModule = { config, ... }: let
    toSshdValue = value:
      if value == true then "yes"
      else if value == false then "no"
      else toString value;
    toSshdConf = key: value: "${key} ${toSshdValue value}";
  in {
    options = with lib.types; {
      openssh.matchBlock = {
        enable = mkEnableOption "match block" // {
          default = config.openssh.matchBlock.settings != { };
        };
        criteria = mkOption {
          type = attrsOf str;
        };
        settings = mkOption {
          type = attrsOf (oneOf [ str path bool int ]);
          default = { };
        };
        settingsConfig = mkOption {
          type = lines;
          default = "";
        };
      };
    };
    config = {
      openssh.matchBlock = {
        criteria = {
          User = mkOptionDefault config.name;
        };
        settingsConfig = mkMerge (
          mapAttrsToList toSshdConf config.openssh.matchBlock.settings
        );
      };
    };
  };
in {
  options = with lib.types; {
    users.users = mkOption {
      type = attrsOf (submodule userModule);
    };
  };
  config = {
    services.openssh.extraConfig = mkMerge (
      map userMatchBlock opensshMatchUsers
    );
  };
}
