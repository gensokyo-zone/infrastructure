{
  pkgs,
  config,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  cfg = config.services.home-assistant;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  sopsFile = mkDefault ./secrets/home-assistant.yaml;
in {
  sops.secrets = mkIf cfg.enable {
    ha-integration = {
      inherit sopsFile;
      owner = "hass";
    };
    ha-secrets = {
      inherit sopsFile;
      owner = "hass";
    };
  };

  services.home-assistant = {
    enable = mkDefault true;
    mutableUiConfig = mkDefault true;
    domain = mkDefault "home.${config.networking.domain}";
    localDomain = mkDefault "home.local.${config.networking.domain}";
    secretsFile = mkDefault config.sops.secrets.ha-secrets.path;
    reverseProxy = {
      enable = mkDefault true;
      trustedAddresses = mkMerge [
        access.cidrForNetwork.int.all
        # [ "200::/7" ]
      ];
    };
    config = {
      homeassistant = {
        name = "Gensokyo";
        unit_system = "metric";
        latitude = "!secret home_lat";
        longitude = "!secret home_long";
        elevation = "!secret home_asl";
        currency = "CAD";
        country = "CA";
        time_zone = "America/Vancouver";
        # media_dirs, allowlist_external_urls, allowlist_external_dirs?
        packages = {
          manual = "!include manual.yaml";
        };
        auth_providers = let
          inherit (lib.attrsets) genAttrs;
          shanghai = with gensokyo-zone.systems.shanghai.network.networks.local; [
            address4
            address6
          ];
          nue = with gensokyo-zone.systems.nue.network.networks.local; [
            address4
            address6
          ];
          logistics = with gensokyo-zone.systems.logistics.network.networks.local; [
            address4
            address6
          ];
          koishi = with gensokyo-zone.systems.koishi.network.networks.local; [
            address4
            #address6
          ];
          guest =
            logistics
            ++ [
              # bedroom tv
              "10.1.1.67"
            ];
          kat = koishi;
          arc = shanghai ++ nue;
          enableTrustedAuth = false;
        in
          mkIf enableTrustedAuth [
            {
              type = "trusted_networks";
              #allow_bypass_login = true;
              trusted_networks = guest;
              trusted_users =
                genAttrs guest (_: "4051fcce77564010a836fd6b108bbb4b")
                #genAttrs arc (_: "0c9c9382890746c2b246b76557f22953")
                #genAttrs kat (_: "a6e96c523d334aabaea71743839ef584")
                ;
            }
            {
              type = "homeassistant";
            }
          ];
      };
      frontend = {
        themes = "!include_dir_merge_named themes";
      };
      powercalc = {
      };
      utility_meter = {
      };
      withings = {
        use_webhook = true;
      };
      recorder = {
        db_url = mkIf (!config.services.postgresql.enable) "!secret db_url";
        auto_purge = true;
        purge_keep_days = 14;
        commit_interval = 1;
        exclude = {
          domains = [
            "automation"
            "updater"
          ];
          entity_globs = [
            "sensor.weather_*"
            "sensor.date_*"
          ];
          entities = [
            "sun.sun"
            "sensor.last_boot"
            "sensor.date"
            "sensor.time"
          ];
          event_types = [
            "call_service"
          ];
        };
      };
      google_assistant = {
        project_id = "gensokyo-5cfaf";
        service_account = "!include ${config.sops.secrets.ha-integration.path}";
        report_state = true;
        exposed_domains = [
          "scene"
          "script"
          #"climate"
          #"sensor"
        ];
        entity_config = {};
      };
      homekit = [
        {
          name = "Tewi";
          port = 21063;
          filter = let
            inherit (cfg.config) google_assistant;
          in {
            include_domains = google_assistant.exposed_domains;
            include_entities = "!include homekit_include_entities.yaml";
          };
          entity_config = "!include homekit_entity_config.yaml";
        }
      ];
      tts = [
        {
          platform = "google_translate";
          service_name = "google_say";
        }
      ];
      media_player = [
        {
          platform = "mpd";
          name = "Shanghai MPD";
          host = "shanghai.local.cutie.moe";
          password = "!secret mpd-shanghai-password";
        }
      ];
      prometheus = {};
      wake_on_lan = {};
    };
    # XXX: broken on new python x.x
    grocy.enable = false;
    extraComponents = [
      "esphome"
      "apple_tv"
      "spotify"
      "brother"
      "ipp"
      "androidtv"
      "cast"
      "discord"
      "nfandroidtv"
      "octoprint"
      "ollama"
      "plex"
      "shopping_list"
      "tile"
      "wake_on_lan"
      "wyoming"
      "whisper"
      "piper"
      "withings"
      "wled"
    ];
    customComponents = [
      pkgs.home-assistant-custom-components.moonraker
    ];
  };
  systemd.services.home-assistant = mkIf cfg.enable {
    gensokyo-zone.sharedMounts.hass.path = mkDefault cfg.configDir;
  };
}
