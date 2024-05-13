{lib, ...}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkOverride;
  mkExtraForce = mkOverride 25;
  locationModule = {
    config,
    virtualHost,
    ...
  }: {
    options = with lib.types; {
      enable =
        mkEnableOption "enable location"
        // {
          default = true;
        };
    };
    config = mkIf (!virtualHost.enable || !config.enable) {
      extraConfig = mkExtraForce "deny all;";
    };
  };
  hostModule = {config, ...}: {
    options = with lib.types; {
      enable =
        mkEnableOption "enable server"
        // {
          default = true;
        };
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [locationModule];
          shorthandOnlyDefinesConfig = true;
        });
      };
    };

    config = mkIf (!config.enable) {
      default = mkExtraForce false;
      extraConfig = mkExtraForce ''
        deny all;
      '';
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submoduleWith {
        modules = [hostModule];
        shorthandOnlyDefinesConfig = true;
      });
    };
  };
}
