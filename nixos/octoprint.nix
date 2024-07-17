{
  config,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) domain;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (config.services) motion;
  cfg = config.services.octoprint;
  vouchHeader = null;
  #vouchHeader = "X-Vouch-User";
in {
  services.octoprint = {
    enable = mkDefault true;
    # host = mkIf config.networking.enableIPv6 "::";
    plugins = python3Packages: with python3Packages; [
      prometheus-exporter
      octorant
      queue
      abl-expert
      bedlevelvisualizer
      #displayprogress / displaylayerprogress?
      marlingcodedocumentation
      printtimegenius
      stlviewer
      #octoklipper?
      #octolapse?
      #dashboard?
    ];
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
          autoconnect = true;
        };
      }
      {
        plugins.octorant = let
          media = {
            none = "none";
            webcam = "snapshot";
            #timelapse = ?;
          };
        in {
          _config_version = 2;
          events = {
            printer_state_error.media = media.none;
            printer_state_operational = {
              enabled = false;
              media = media.none;
            };
            printer_state_unknown.media = media.none;
            printing_started = {
              message = "New print started: **{name}**";
            };
            printing_cancelled = {
              message = "Print cancelled after {time_formatted}";
            };
            printing_paused = {
              message = "Print paused";
              media = media.none;
            };
            printing_failed.message = "Print failed! :<";
            printing_progress.message = "Printed **{progress}%** with {remaining_formatted} remaining";
            printing_resumed = {
              message = "Print resumed";
              media = media.none;
            };
            shutdown = {
              #enabled = false;
              media = media.none;
            };
            startup = {
              #enabled = false;
              media = media.none;
            };
            timelapse_done = {
              enabled = true;
              # TODO: movie_basename needs uri encoding if it contains spaces .-.
              message = "Timelapse for {gcode}: [{movie_basename}](https://print.${domain}/downloads/timelapse/{movie_basename_uri})";
              media = media.none;
            };
            timelapse_failed.media = media.none;
            transfer_done.media = media.none;
            transfer_failed.media = media.none;
            transfer_progress.media = media.none;
            progress = {
              #percentage_enabled = false;
              percentage_step = "14";
              throttle_enabled = true;
              time_enabled = true;
              throttle_step = "540";
              time_step = "600";
            };
          };
          # TODO: url = "https://discord.com/api/webhooks/etc";
        };
      }
      (mkIf motion.enable {
        webcam = {
          bitrate = "6000k";
          ffmpegThreads = 2;
          timelapse = {
            fps = 25;
            options.interval = 3;
            postRoll = 0;
            type = "timed";
          };
        };
        plugins = {
          classicwebcam = let
            inherit (motion.cameras) printercam;
            inherit (printercam.settings) camera_id;
          in {
            _config_version = 1;
            snapshot = "https://kitchen.local.${domain}/${toString camera_id}/current";
            stream = "https://kitchen.local.${domain}/${toString camera_id}/stream";
            streamRatio = "4:3";
          };
        };
      })
      (mkIf (vouchHeader == null) {
        accessControl = {
          autologinLocal = true;
          autologinHeadsupAcknowledged = true;
          #autologinAs = "guest";
          autologinAs = "admin";
          localNetworks = access.cidrForNetwork.allLocal.all
          ++ [
            # vouch protects it from the outside world so...
            "0.0.0.0/0"
            "::/0"
          ];
        };
      })
      (mkIf (vouchHeader != null) {
        accessControl = {
          trustRemoteUser = true;
          addRemoteUsers = true;
          remoteUserHeader = vouchHeader;
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
