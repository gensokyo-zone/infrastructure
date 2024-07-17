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
    width = 1280;
    height = 720;
    framerate = 5;
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
