{
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapDefaults;
  inherit (config.services) motion;
in {
  services.motion.cameras.kitchencam.settings = mapDefaults {
    videodevice = "/dev/kitchencam";
    video_params = "auto_brightness=2,palette=8"; # MJPG=8, YUYV=15
    width = 1280;
    height = 720;
    framerate = 2;
    camera_id = 1;
    text_left = "kitchen";
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
      ''OWNER="${motion.user}"''
      ''TAG+="systemd"''
      ''ENV{SYSTEMD_WANTS}="motion.service"''
    ];
    rulesLine = concatStringsSep ", " rules;
  in
    rulesLine;
}
