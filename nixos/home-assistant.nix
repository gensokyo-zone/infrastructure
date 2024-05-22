{
  config,
  lib,
  ...
}: let
  cfg = config.services.home-assistant;
  inherit (lib.modules) mkIf mkDefault;
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
    secretsFile = mkDefault config.sops.secrets.ha-secrets.path;
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
        packages = {
          manual = "!include manual.yaml";
        };
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
    grocy.enable = true;
    extraComponents = [
      "zha"
      "esphome"
      "apple_tv"
      "spotify"
      "brother"
      "ipp"
      "androidtv"
      "cast"
      "nfandroidtv"
      "plex"
      "shopping_list"
      "tile"
      "wake_on_lan"
      "withings"
      "wled"
    ];
  };
  systemd.services.home-assistant = mkIf cfg.enable {
    gensokyo-zone.sharedMounts.hass.path = mkDefault cfg.configDir;
  };
}
