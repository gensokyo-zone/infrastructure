{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (config.networking) hostName;
in {
  options.networking.access = with lib.types; {
    hostnameForNetwork = mkOption {
      type = attrsOf str;
      default = { };
    };
  };

  config.networking.access = {
    hostnameForNetwork = {
      local = mkIf config.services.avahi.enable "${hostName}.local.gensokyo.zone";
      tail = mkIf config.services.tailscale.enable "${hostName}.tail.gensokyo.zone";
      global = mkIf config.networking.enableIPv6 "${hostName}.gensokyo.zone";
    };
  };
}
