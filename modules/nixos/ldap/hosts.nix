{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
in {
  options.users.ldap = with lib.types; {
    domainDnSuffix = mkOption {
      type = str;
      default = "";
    };
    hostDnSuffix = mkOption {
      type = str;
      default = "";
    };
    serviceDnSuffix = mkOption {
      type = str;
      default = "";
    };
    sysAccountDnSuffix = mkOption {
      type = str;
      default = "";
    };
  };
}
