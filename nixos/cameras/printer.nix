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
    videodevice = "/dev/printercam";
    video_params = "auto_brightness=1,palette=8"; # MJPG=8, YUYV=15
    width = 1920;
    height = 1080;
    framerate = 2;
    camera_id = 2;
    text_left = "";
    #text_right = "";
  };
  services.udev.extraRules = let
    inherit (lib.strings) concatStringsSep;
    rules = [
      ''SUBSYSTEM=="video4linux"''
      ''ACTION=="add"''
      ''ATTR{index}=="0"''
      ''ATTRS{idProduct}=="6366"''
      ''ATTRS{idVendor}=="0c45"''
      ''SYMLINK+="printercam"''
      ''OWNER="${motion.user}"''
      ''TAG+="systemd"''
      ''ENV{SYSTEMD_WANTS}="motion.service"''
    ];
    rulesLine = concatStringsSep ", " rules;
  in rulesLine;
}
