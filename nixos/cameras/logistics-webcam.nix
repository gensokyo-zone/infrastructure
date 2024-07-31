{gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapDefaults;
in {
  services.motion.cameras.webcam.settings = mapDefaults {
    videodevice = "/dev/video0";
    camera_id = 3;
    text_left = "logistics";
  };
}
