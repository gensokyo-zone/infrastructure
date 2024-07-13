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
          firstRun = false;
          onlineCheck.enabled = true;
          pluginBlacklist.enabled = true;

          # TODO: secretKey = sops?
          reverseProxy = {
            hostHeader = "X-Forwarded-Host";
            schemeHeader = "X-Forwarded-Proto";
            trustedDownstream = access.cidrForNetwork.allLan.all;
          };
        };
        plugins = {
          _disabled = [
            "softwareupdate"
          ];
        };
        temperature = {
          profiles = [
            {
              name = "ABS";
              bed = 100;
              extruder = 210;
              chamber = null;
            }
            {
              name = "PLA";
              bed = 60;
              extruder = 180;
              chamber = null;
            }
          ];
        };
        serial = {
          port = "/dev/ttyUSB0";
          baudrate = 115200;
          #autoconnect = true;
        };
      }
      (mkIf motion.enable {
        webcam = {
          # TODO
        };
      })
      (mkIf (!behindVouch) {
        accessControl = {
          autologinLocal = true;
          #autologinAs = "guest";
          autologinAs = "admin";
          localNetworks = access.cidrForNetwork.allLocal.all;
        };
      })
      (mkIf behindVouch {
        accessControl = {
          trustRemoteUser = true;
          addRemoteUsers = true;
          remoteUserHeader = "X-Vouch-User";
        };
      })
    ];
  };

  networking.firewall = mkIf cfg.enable {
    interfaces.lan.allowedTCPPorts = [
      cfg.port
    ];
  };
}
