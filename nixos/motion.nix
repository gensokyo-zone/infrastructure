{
  pkgs,
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapDefaults;
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.motion;
  streamPort = 41081;
  webPort = 8080;
in {
  services.motion = {
    enable = mkDefault true;
    settings = mapDefaults {
      picture_output = false;
      movie_output = false;
      picture_filename = "%Y%m%d%H%M%S-%q";
      movie_filename = "%t-%v-%Y%m%d%H%M%S";
      movie_passthrough = true;
      pause = true;

      text_right = "%Y-%m-%d\\n%T-%q";
      threshold = 1500;
      despeckle_filter = "EedDl";
      minimum_motion_frames = 1;
      event_gap = 60;
      pre_capture = 3;
      post_capture = 0;

      webcontrol_localhost = false;
      stream_localhost = false;
      webcontrol_parms = 0;
      webcontrol_port = webPort;
      stream_port = streamPort;

      stream_maxrate = 30;
      stream_quality = 75;
    };
  };
  systemd.services.motion = mkIf cfg.enable {
    serviceConfig.LogFilterPatterns = [
      ''~Corrupt image \.\.\. continue''
      ''~Invalid JPEG file structure: missing SOS marker''
    ];
  };
  networking.firewall.interfaces.local = mkIf cfg.enable {
    allowedTCPPorts = [cfg.settings.stream_port cfg.settings.webcontrol_port];
  };
  environment.systemPackages = [
    pkgs.v4l-utils
  ];
}
