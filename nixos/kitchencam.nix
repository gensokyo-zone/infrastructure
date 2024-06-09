{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.motion;
  streamPort = 41081;
  webPort = 8080;
in {
  services.motion = {
    enable = mkDefault true;
    extraConfig = ''
      videodevice /dev/kitchencam
      v4l2_palette 8
      width 640
      height 480
      framerate 5

      text_left kitchen
      text_right %Y-%m-%d\n%T-%q
      emulate_motion off
      threshold 1500
      despeckle_filter EedDl
      minimum_motion_frames 1
      event_gap 60
      pre_capture 3
      post_capture 0

      picture_output off
      picture_filename %Y%m%d%H%M%S-%q

      movie_output off
      movie_max_time 60
      movie_quality 45
      movie_codec mkv
      movie_filename %t-%v-%Y%m%d%H%M%S

      webcontrol_port ${toString webPort}
      webcontrol_localhost off
      webcontrol_parms 0
      stream_port ${toString streamPort}
      stream_localhost off
      ipv6_enabled on
    '';
  };
  services.udev.extraRules = let
    inherit (lib.strings) concatStringsSep;
    rules = [
      ''SUBSYSTEM=="video4linux"''
      ''ACTION=="add"''
      ''ATTR{index}=="0"''
      ''ATTRS{idProduct}=="2a25"''
      ''ATTRS{idVendor}=="1224"''
      ''SYMLINK+="kitchencam"''
      ''OWNER="${cfg.user}"''
      ''TAG+="systemd"''
      ''ENV{SYSTEMD_WANTS}="motion.service"''
    ];
    rulesLine = concatStringsSep ", " rules;
  in
    mkIf cfg.enable rulesLine;
  networking.firewall.interfaces.local = mkIf cfg.enable {
    allowedTCPPorts = [streamPort webPort];
  };
}
