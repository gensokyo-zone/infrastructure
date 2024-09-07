{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.syncplay;
in {
  sops.secrets = let
    sopsFile = mkDefault ./secrets/syncplay.yaml;
  in
    mkIf cfg.enable {
      syncplay-password = {
        inherit sopsFile;
      };
      syncplay-salt = {
        inherit sopsFile;
      };
    };

  services.syncplay = {
    enable = mkDefault true;
    extraArgs = [
      "--disable-ready"
    ];
    saltFile = mkDefault config.sops.secrets.syncplay-salt.path;
    passwordFile = mkDefault config.sops.secrets.syncplay-password.path;
  };

  networking.firewall = mkIf (cfg.enable && !cfg.openFirewall) {
    interfaces.local.allowedTCPPorts = [cfg.port];
  };
}
