{config, lib, ...}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  inherit (lib.lists) filter optional;
  inherit (lib.strings) hasInfix concatStrings;
  inherit (config.services) resolved;
  enabledNameservers = filter (ns: ns.enable) (config.networking.nameservers');
  nameserverModule = {config, ...}: let
    dnsPort = 53;
    mkResolvedValue = { address, port, interface ? null, host ? null }: let
      isIpv6 = hasInfix ":" address;
      isPlain = port == dnsPort && interface == null && host == null;
      addr = if isIpv6 && !isPlain then "[${address}]" else address;
    in concatStrings (
      [ addr ]
      ++ optional (port != dnsPort) ":${toString port}"
      ++ optional (interface != null) "%${interface}"
      ++ optional (host != null) "#${host}"
    );
  in {
    options = with lib.types; {
      enable = mkEnableOption "nameserver" // {
        default = true;
      };
      address = mkOption {
        type = str;
      };
      port = mkOption {
        type = port;
        default = dnsPort;
      };
      interface = mkOption {
        type = nullOr str;
        default = null;
      };
      host = mkOption {
        type = nullOr str;
        default = null;
      };
      resolvedValue = mkOption {
        type = str;
        readOnly = true;
      };
      value = mkOption {
        type = str;
        internal = true;
      };
    };
    config = {
      resolvedValue = mkOptionDefault (mkResolvedValue {
        inherit (config) address port interface host;
      });
      value = mkOptionDefault (mkResolvedValue {
        inherit (config) address port;
      });
    };
  };
in {
  options.networking = with lib.types; {
    nameservers' = mkOption {
      type = listOf (submodule nameserverModule);
      default = { };
    };
  };
  config = {
    networking.nameservers = mkIf (config.networking.nameservers' != [ ]) (
      map (ns: if resolved.enable then ns.resolvedValue else ns.value) enabledNameservers
    );
  };
}
