{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.wyoming.openwakeword;
in {
  imports = [./wyoming.nix];
  services.wyoming.openwakeword = {
    enable = mkDefault true;
    uri = mkDefault "tcp://0.0.0.0:10400";
    # models: https://github.com/dscripka/openWakeWord?tab=readme-ov-file#pre-trained-models
    preloadModels = mkDefault [
      "ok_nabu"
      "hey_rhasspy"
    ];
  };

  # allow access to LAN satellites
  networking.firewall.interfaces.local.allowedTCPPorts = mkIf cfg.enable [cfg.port];
}
