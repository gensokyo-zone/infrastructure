{
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (config.services) motion;
  inherit (gensokyo-zone.lib) mapDefaults;
in {
  services.motion.cameras.webcam.settings = mapDefaults {
    video_device = "/dev/webcam";
    video_params = "palette=15";
    width = 1280;
    height = 720;
    camera_id = 3;
    framerate = 3;
    text_left = "logistics";
  };
  services.udev.extraRules = let
    inherit (lib.strings) concatStringsSep;
    rules = [
      ''SUBSYSTEM=="video4linux"''
      ''ATTR{index}=="0"''
      ''ATTRS{idVendor}=="5986"''
      ''ATTRS{idProduct}=="111c"''
      ''SYMLINK+="webcam"''
      ''OWNER="${motion.user}"''
      ''TAG+="systemd"''
      ''ENV{SYSTEMD_WANTS}="motion.service"''
    ];
    rulesLine = concatStringsSep ", " rules;
  in
    rulesLine;
}
