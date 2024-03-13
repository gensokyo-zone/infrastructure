{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault mkIf;
  cfg = config.services.mediatomb;
in {
  config.services.mediatomb = {
    enable = mkDefault true;
    port = mkDefault 4152;
    uuid = mkDefault "082fd344-bf69-5b72-a68f-a5a4d88e76b2";
  };
  config.users.users = mkIf cfg.enable {
    ${cfg.user}.extraGroups = ["kyuuto"];
  };
}
