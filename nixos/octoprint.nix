{
  config,
  access,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (config.services) motion;
  cfg = config.services.octoprint;
  behindVouch = false;
in {
  services.octoprint = {
    enable = mkDefault true;
    # host = mkIf config.networking.enableIPv6 "::";
    extraConfig = mkMerge [
      # https://docs.octoprint.org/en/master/configuration/config_yaml.html
      {
        # TODO: api.key = sops?
        server = {
          # TODO: secretKey = sops?
          reverseProxy = {
            schemeHeader = "X-Forwarded-Proto";
            trustedDownstream = access.cidrForNetwork.allLan.all;
          };
        };
        webcam = mkIf motion.enable {
          # TODO
        };
        plugins = {
          _disabled = [
            "softwareupdate"
          ];
        };
      }
      (mkIf (!behindVouch) {
        autologinLocal = true;
        autologinAs = "guest";
        localNetworks = access.cidrForNetwork.allLocal.all;
      })
      (mkIf behindVouch {
        trustRemoteUser = true;
        addRemoteUsers = true;
        remoteUserHeader = "X-Vouch-User";
      })
    ];
  };

  networking.firewall = mkIf cfg.enable {
    interfaces.lan.allowedTCPPorts = [
      cfg.port
    ];
  };
}
