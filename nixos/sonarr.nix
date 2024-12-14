{config, lib, ...}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.sonarr;
  available = cfg.package.meta.available && cfg.package.dotnet-runtime.meta.available or true && lib.versionAtLeast cfg.package.dotnet-runtime.version or "8.0" "8.0";
in {
  services.sonarr = {
    enable = mkIf available (mkDefault true);
  };
  users.users.sonarr.extraGroups = ["kyuuto"];
}
