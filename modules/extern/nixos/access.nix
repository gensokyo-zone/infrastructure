{
  config,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  cfg = config.gensokyo-zone.access;
  accessModule = {
    gensokyo-zone,
    nixosConfig,
    config,
    ...
  }: {
    options = with lib.types; {
      tail = {
        enable = mkEnableOption "tailscale access";
        enabled = mkOption {
          type = bool;
          readOnly = true;
        };
      };
      local.enable = mkEnableOption "local access";
    };
    config = {
      tail.enabled = config.tail.enable && nixosConfig.services.tailscale.enable;
    };
  };
in {
  options.gensokyo-zone.access = mkOption {
    type = lib.types.submoduleWith {
      modules = [accessModule];
      specialArgs = {
        inherit gensokyo-zone;
        nixosConfig = config;
      };
    };
    default = { };
  };

  config = {
    lib.gensokyo-zone.access = {
      inherit cfg accessModule;
    };
  };
}
