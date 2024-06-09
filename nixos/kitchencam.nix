{
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

      text_right = "%Y-%m-%d\\n%T-%q";
      emulate_motion = false;
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
    };
    cameras.kitchencam.settings = mapDefaults {
      videodevice = "/dev/kitchencam";
      v4l2_palette = 8;
      width = 640;
      height = 480;
      framerate = 5;
      camera_id = 1;
      text_left = "kitchen";
    };
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
    allowedTCPPorts = [cfg.settings.stream_port cfg.settings.webcontrol_port];
  };
}
