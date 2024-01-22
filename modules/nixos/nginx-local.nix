{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkBefore;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.strings) concatMapStringsSep;
  inherit (lib.lists) optionals;
  inherit (config.services) tailscale;
  inherit (config.networking.access) cidrForNetwork;
  localModule = { config, ... }: {
    options = with lib.types; {
      local = {
        enable = mkEnableOption "local traffic only";
      };
    };
    config = mkIf config.local.enable {
      extraConfig = let
        mkAllow = cidr: "allow ${cidr};";
        allowAddresses =
          cidrForNetwork.loopback.all
          ++ cidrForNetwork.local.all
          ++ optionals tailscale.enable cidrForNetwork.tail.all;
        allows = concatMapStringsSep "\n" mkAllow allowAddresses;
      in mkBefore ''
        ${allows}
        deny all;
      '';
    };
  };
  hostModule = { config, ... }: {
    imports = [ localModule ];

    options = with lib.types; {
      locations = mkOption {
        type = attrsOf (submodule localModule);
      };
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submodule hostModule);
    };
  };
}
