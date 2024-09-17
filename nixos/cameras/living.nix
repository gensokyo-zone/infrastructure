{
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapDefaults;
  inherit (lib.strings) concatStringsSep;
  inherit (config.services) motion;
  format = "mjpeg"; # or "yuyv"
  params = {
    mjpeg = {
      palette = 8;
      width = 1280;
      height = 720;
    };
    yuyv = {
      palette = 15;
      width = 640;
      height = 480;
    };
  };
in {
  services.motion.cameras.livingcam.settings = mapDefaults {
    video_device = "/dev/livingcam";
    video_params = concatStringsSep "," [
      #"auto_brightness=2"
      "brightness=56"
      "power_line_frequency=2"
      "palette=${toString params.${format}.palette}"
    ];
    inherit (params.${format}) width height;
    #framerate = 30;
    framerate = 20;
    camera_id = 4;
    text_left = "";
    text_right = "";
    stream_quality = 85;
  };
  services.udev.extraRules = let
    inherit (lib.strings) concatStringsSep;
    rules = [
      ''SUBSYSTEM=="video4linux"''
      ''ATTR{index}=="0"''
      ''ATTRS{idVendor}=="1d3f"''
      ''ATTRS{idProduct}=="1120"''
      ''SYMLINK+="livingcam"''
      ''OWNER="${motion.user}"''
      ''TAG+="systemd"''
      ''ENV{SYSTEMD_WANTS}="motion.service"''
    ];
    rulesLine = concatStringsSep ", " rules;
  in
    rulesLine;
}
