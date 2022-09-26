{ config, lib, tf, ... }: {
  # MDNS
  services.avahi.enable = true;

  networks.gensokyo = {
    tcp = [
      # Home Assistant
      8123
      # Tewi Homekit
      21063
    ];
    udp = [
      # Chromecast
      [ 32768 60999 ]
      # MDNS
      5353
    ];
  };

  kw.secrets.variables.ha-integration = {
    path = "secrets/home-assistant";
    field = "notes";
  };

  secrets.files.ha-integration = {
    text = tf.variables.ha-integration.ref;
    owner = "hass";
    group = "hass";
  };

  systemd.services.home-assistant = {
    preStart = lib.mkBefore ''
      rm ${config.services.home-assistant.configDir}/integration.json
      cp --no-preserve=mode ${config.secrets.files.ha-integration.path} ${config.services.home-assistant.configDir}/integration.json
      '';
  };

  services.home-assistant = {
    enable = true;
    config = {
      homeassistant = {
        name = "Gensokyo";
        unit_system = "metric";
        external_url = "https://home.gensokyo.zone";
      };
      logger = {
        default = "info";
      };
      http = {
        cors_allowed_origins = [
          "https://google.com"
            "https://www.home-assistant.io"
        ];
        use_x_forwarded_for = "true";
        trusted_proxies = [
          "127.0.0.0/24"
            "200::/7"
            "100.64.0.0/10"
            "fd7a:115c:a1e0:ab12::/64"
        ];
      };
      recorder = {
        db_url = "postgresql://@/hass";
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
        service_account = "!include integration.json";
      };
      homekit = {
        name = "Tewi";
        port = 21063;
        ip_address = "10.1.1.38";
      };
      tts = [{
        platform = "google_translate";
        service_name = "google_say";
      }];
      automation = {};
      counter = {};
      device_tracker = {};
      energy = {};
      frontend = {};
      group = {};
      history = {};
      image = {};
      input_boolean = {};
      input_datetime = {};
      input_number = {};
      input_select = {};
      input_text = {};
      logbook = {};
      map = {};
      media_source = {};
      mobile_app = {};
      my = {};
      person = {};
      scene = {};
      script = {};
      ssdp = {};
      switch = {};
      stream = {};
      sun = {};
      system_health = {};
      tag = {};
      template = {};
      timer = {};
      webhook = {};
      wake_on_lan = {};
      zeroconf = {};
      zone = {};
    };
    extraPackages = python3Packages: with python3Packages; [
      psycopg2
      aiohomekit
      securetar
    ];
    extraComponents = [
      "zha"
      "esphome"
      "apple_tv"
      "spotify"
      "default_config"
      "cast"
      "plex"
      "met"
      "google"
      "google_assistant"
      "google_cloud"
      "google_translate"
      "homekit"
      "mqtt"
      "wake_on_lan"
      "zeroconf"
    ];
  };
}