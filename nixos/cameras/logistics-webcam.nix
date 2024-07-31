{gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapDefaults;
in {
  services.motion.cameras.webcam.settings = mapDefaults {
    video_device = "/dev/video0";
    video_params = "palette=15";
    width = 1280;
    height = 720;
    camera_id = 3;
    framerate = 3;
    text_left = "logistics";
  };
}
