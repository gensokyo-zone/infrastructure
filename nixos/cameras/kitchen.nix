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
    v4l2_palette = 8;
    width = 640;
    height = 480;
    framerate = 5;
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
  in rulesLine;
}
