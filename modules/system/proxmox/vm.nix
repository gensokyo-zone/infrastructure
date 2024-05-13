{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  cfg = config.proxmox;
in {
  options.proxmox = with lib.types; {
    enabled = mkOption {
      type = bool;
      default = cfg.vm.enable || cfg.container.enable;
      readOnly = true;
    };
    vm = {
      enable = mkEnableOption "QEMU VM";
      id = mkOption {
        type = int;
      };
    };
    node.name = mkOption {
      type = str;
      default = "reisen";
    };
  };
}
