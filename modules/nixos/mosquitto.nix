{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkMerge mkEnableOption mkOption;
  cfg = config.services.mosquitto;
in {
  options.services.mosquitto = with lib.types; {
    listeners = let
      listenerModule = { ... }: {
        options = {
          openFirewall = mkEnableOption "firewall";
        };
      };
    in mkOption {
      type = listOf (submodule listenerModule);
    };
  };
  config = {
    networking.firewall.allowedTCPPorts = mkIf cfg.enable (mkMerge (
      map (listener: mkIf listener.openFirewall [ listener.port ]) cfg.listeners
    ));
  };
}
