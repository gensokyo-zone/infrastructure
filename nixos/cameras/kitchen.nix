{
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapDefaults;
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
  services.motion.cameras.kitchencam.settings = mapDefaults {
    video_device = "/dev/kitchencam";
    video_params = "auto_brightness=2,palette=${toString params.${format}.palette}";
    inherit (params.${format}) width height;
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
