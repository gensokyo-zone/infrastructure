{ config, pkgs, nixos, lib, ... }:


{
  home.packages = [
    config.services.konawall.konashow
  ];

  services.konawall = {
    enable = true;
    interval = "30m";
    mode = "shuffle";
    commonTags = [ "width:>=1600" ];
    tagList = map (lib.toList) [
      (["score:>=50"
      "touhou" "rating:s"]) #++ optional (nixos.networking.hostName == "koishi") "rating:s")
    ];
  };
}
