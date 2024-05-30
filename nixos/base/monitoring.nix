{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  services = {
    prometheus.exporters.node.enable = mkDefault true;
    promtail.enable = mkDefault true;
  };
}
