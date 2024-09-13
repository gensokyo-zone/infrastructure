{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkForce mkDefault;
  cfg = config.services.wyoming.faster-whisper;
  inherit (cfg.servers) whisper;
  useRocm = false; # broken...
in {
  imports = [./wyoming.nix];
  services.wyoming.faster-whisper = {
    # models: https://github.com/rhasspy/wyoming-faster-whisper/releases/tag/v2.0.0
    servers.whisper = {
      enable = mkDefault true;
      language = mkDefault "en";
      model = let
        #distil = "distil";
        #distil = "distil-whisper/distil-whisper";
        distil = "Systran/faster-distil-whisper";
        #size = "small.en";
        size = "medium.en";
        #size = "large-v3";
      in
        mkDefault "${distil}-${size}";
      uri = mkDefault "tcp://0.0.0.0:10300";
      device = mkIf useRocm "cuda";
    };
  };
  systemd.services.wyoming-faster-whisper-whisper = mkIf whisper.enable {
    serviceConfig = mkIf (whisper.device != "cpu" && useRocm) {
      DeviceAllow = [
        "char-drm"
        "char-kfd"
      ];
      SupplementaryGroups = ["render"];
      PrivateDevices = mkForce false;
    };
  };
}
