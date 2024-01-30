{
  config,
  lib,
  ...
}: let
  cfg = config.services.home-assistant;
  inherit (lib.modules) mkIf mkDefault;
  sopsFile = mkDefault ./secrets/home-assistant.yaml;
in {
  sops.secrets = {
    ha-integration = {
      inherit sopsFile;
      owner = "hass";
      path = "${cfg.configDir}/integration.yaml";
    };
    ha-secrets = {
      inherit sopsFile;
      owner = "hass";
      path = "${cfg.configDir}/secrets.yaml";
    };
  };

  services.home-assistant = {
    enable = mkDefault true;
    mutableUiConfig = mkDefault true;
    domain = mkDefault "home.${config.networking.domain}";
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
        service_account = "!include integration.yaml";
        report_state = true;
        exposed_domains = [
          "scene"
          "script"
          #"climate"
          #"sensor"
        ];
        entity_config = {};
      };
      homekit = [ {
        name = "Tewi";
        port = 21063;
        filter = let
          inherit (cfg.config) google_assistant;
        in {
          include_domains = google_assistant.exposed_domains;
          include_entities = "!include homekit_include_entities.yaml";
        };
        entity_config = "!include homekit_entity_config.yaml";
      } ];
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
    extraComponents = [
      "zha"
      "esphome"
      "apple_tv"
      "spotify"
      "brother"
      "ipp"
      "androidtv"
      "cast"
      "plex"
      "shopping_list"
      "tile"
      "wake_on_lan"
      "withings"
      "wled"
    ];
  };
}
