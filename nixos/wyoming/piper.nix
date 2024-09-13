{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  imports = [./wyoming.nix];
  services.wyoming.piper = {
    # voices: https://rhasspy.github.io/piper-samples/
    servers.piper = {
      enable = mkDefault true;
      uri = mkDefault "tcp://0.0.0.0:10200";
      voice = mkDefault "en_GB-semaine-medium";
      speaker = mkDefault 0;
    };
  };
}
