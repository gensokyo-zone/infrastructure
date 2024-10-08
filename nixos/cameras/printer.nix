{
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapDefaults;
  inherit (config.services) motion;
in {
  services.motion.cameras.printercam.settings = mapDefaults {
    video_device = "/dev/printercam";
    video_params = "auto_brightness=0,sharpness=5,palette=8"; # MJPG=8, YUYV=15
    width = 1920;
    height = 1080;
    framerate = 4;
    camera_id = 2;
    text_left = "";
    #text_right = "";
  };
  services.udev.extraRules = let
    inherit (lib.strings) concatStringsSep;
    rules = [
      ''SUBSYSTEM=="video4linux"''
      ''ATTR{index}=="0"''
      ''ATTRS{idVendor}=="0c45"''
      ''ATTRS{idProduct}=="6366"''
      ''SYMLINK+="printercam"''
      ''OWNER="${motion.user}"''
      ''TAG+="systemd"''
      ''ENV{SYSTEMD_WANTS}="motion.service"''
    ];
    rulesLine = concatStringsSep ", " rules;
  in
    rulesLine;
}
