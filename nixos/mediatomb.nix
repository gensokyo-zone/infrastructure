{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault mkIf;
  cfg = config.services.mediatomb;
  gerberaUpdated = lib.versionAtLeast config.services.mediatomb.package.version "1.12.2";
in {
  config.services.mediatomb = {
    enable = mkIf gerberaUpdated (mkDefault true);
    port = mkDefault 4152;
    uuid = mkDefault "082fd344-bf69-5b72-a68f-a5a4d88e76b2";
    openFirewall = false;
  };
  config.users.users = mkIf cfg.enable {
    ${cfg.user}.extraGroups = ["kyuuto"];
  };
  config.networking.firewall.interfaces.local = mkIf cfg.enable {
    allowedTCPPorts = [cfg.port 1900];
    allowedUDPPorts = [1900];
  };
}
