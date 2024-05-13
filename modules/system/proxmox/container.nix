{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  cfg = config.proxmox.container;
in {
  options.proxmox.container = with lib.types; {
    enable = mkEnableOption "LXC container";
    privileged = mkEnableOption "root";
    lxc = {
      configJsonFile = mkOption {
        type = nullOr path;
        default = null;
      };
    };
  };
}
