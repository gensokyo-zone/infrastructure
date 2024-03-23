{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.trivial) toHexString;
  cfg = config.access.internal;
  offset = 32;
in {
  options.access = with lib.types; {
    internal = {
      enable = mkEnableOption "eth9";
      macAddress = mkOption {
        type = nullOr str;
        default = null;
      };
      vmid = mkOption {
        type = int;
      };
      address4 = mkOption {
        type = str;
      };
      address6 = mkOption {
        type = str;
      };
    };
  };
  config.access.internal = {
    address4 = mkOptionDefault "10.9.1.${toString (cfg.vmid - offset)}";
    address6 = mkOptionDefault "fd0c::${toHexString (cfg.vmid - offset)}";
  };
  config.systemd.network.networks.eth9 = mkIf cfg.enable {
    mdns.enable = false;
    name = mkDefault "eth9";
    matchConfig = {
      MACAddress = mkIf (cfg.macAddress != null) (mkOptionDefault cfg.macAddress);
      Type = mkOptionDefault "ether";
    };
    linkConfig.RequiredForOnline = mkOptionDefault false;
    address = mkMerge [
      ["${cfg.address4}/24"]
      (mkIf config.networking.enableIPv6 [ "${cfg.address6}/64" ])
    ];
    DHCP = "no";
  };
}
