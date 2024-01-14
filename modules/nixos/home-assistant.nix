{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.services.home-assistant;
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.lists) optional elem;
  inherit (lib.strings) toLower;
in {
  options.services.home-assistant = with lib.types; {
    mutableUiConfig = mkEnableOption "UI-editable config files";
    domain = mkOption {
      type = str;
      default = config.networking.domain;
    };
    homekit.enable = mkEnableOption "homekit" // {
      default = cfg.config.homekit or [ ] != [ ];
    };
    googleAssistant.enable = mkEnableOption "Google Assistant" // {
      default = cfg.config.google_assistant or { } != { };
    };
    androidTv.enable = mkEnableOption "Android TV" // {
      default = elem "androidtv" cfg.extraComponents;
    };
    cast = {
      enable = mkEnableOption "Chromecast" // {
        default = elem "cast" cfg.extraComponents;
      };
      openFirewall = mkEnableOption "Chromecast ports" // {
        default = cfg.openFirewall;
      };
    };
  };

  config = {
    networking.firewall = mkIf cfg.enable {
      allowedTCPPorts = mkIf (cfg.openFirewall && cfg.homekit.enable) (
        map ({ port, ... }: port) cfg.config.homekit or [ ]
      );

      allowedUDPPortRanges = [
        (mkIf (cfg.cast.enable && cfg.cast.openFirewall) {
          from = 32768;
          to = 60999;
        })
      ];
    };

    # MDNS
    services.avahi = mkIf (cfg.enable && cfg.homekit.enable) {
      enable = mkDefault true;
      publish.enable = let
        homekitNames = map (homekit: toLower homekit.name) cfg.config.homekit or [ ];
      in mkIf (elem config.networking.hostName homekitNames) false;
    };

    systemd.services.home-assistant = mkIf (cfg.enable && cfg.mutableUiConfig) {
      # UI-editable config files
      preStart = mkBefore ''
        touch ${cfg.configDir}/{automations,scenes,scripts,manual,homekit_entity_config,homekit_include_entities}.yaml
      '';
    };
  };

  config.services.home-assistant = {
    config = mkMerge [
      {
        homeassistant = {
          external_url = "https://${cfg.domain}";
        };
        logger = {
          default = mkDefault "info";
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
            "fd7a:115c:a1e0::/96"
            "10.1.1.0/24"
            "fd0a::/64"
            "::1"
          ];
        };
        recorder = {
          db_url = mkIf config.services.postgresql.enable (mkDefault "postgresql://@/hass");
        };
        counter = {};
        device_tracker = {};
        energy = {};
        group = {};
        history = {};
        input_boolean = {};
        input_button = {};
        input_datetime = {};
        input_number = {};
        input_select = {};
        input_text = {};
        logbook = {};
        schedule = {};
        map = {};
        media_source = {};
        media_player = [];
        mobile_app = {};
        my = {};
        person = {};
        ssdp = {};
        switch = {};
        stream = {};
        sun = {};
        system_health = {};
        tag = {};
        template = {};
        timer = {};
        webhook = {};
        zeroconf = {};
        zone = {};
        sensor = {};
      }
      (mkIf cfg.mutableUiConfig {
        # https://nixos.wiki/wiki/Home_Assistant#Combine_declarative_and_UI_defined_automations
        "automation manual" = [];
        "automation ui" = "!include automations.yaml";
        # https://nixos.wiki/wiki/Home_Assistant#Combine_declarative_and_UI_defined_scenes
        "scene manual" = [];
        "scene ui" = "!include scenes.yaml";
        "script manual" = [];
        "script ui" = "!include scripts.yaml";
      })
    ];
    package = let
      inherit (cfg.package) python;
      hasBrother = elem "brother" cfg.extraComponents;
      # https://github.com/pysnmp/pysnmp/issues/51
      needsPyasn1pin = if lib.versionOlder python.pkgs.pysnmplib.version "6.0"
        then true
        else lib.warn "pyasn1 pin likely no longer needed" false;
      pyasn1prefix = "${python.pkgs.pysnmp-pyasn1}/${python.sitePackages}";
      home-assistant = pkgs.home-assistant.override {
        packageOverrides = self: super: {
        };
      };
    in home-assistant.overrideAttrs (old: {
      makeWrapperArgs = old.makeWrapperArgs ++ optional (hasBrother && needsPyasn1pin) "--prefix PYTHONPATH : ${pyasn1prefix}";
      disabledTests = old.disabledTests or [ ] ++ [
        "test_check_config"
      ];
    });
    extraPackages = python3Packages: with python3Packages; mkMerge [
      [
        psycopg2
        securetar
        getmac # for upnp integration
        python-otbr-api
        protobuf3
        (aiogithubapi.overrideAttrs (_: {doInstallCheck = false;}))
      ]
      (mkIf cfg.homekit.enable [
        aiohomekit
      ])
      (mkIf cfg.androidTv.enable [
        adb-shell
        (callPackage ../../packages/androidtvremote2.nix { })
      ])
    ];
    extraComponents = mkMerge [
      [
        "automation"
        "scene"
        "script"
        "default_config"
        "environment_canada"
        "met"
        "generic_thermostat"
        "mqtt"
        "zeroconf"
      ]
      (mkIf cfg.homekit.enable [
        "homekit"
      ])
      (mkIf cfg.googleAssistant.enable [
        "google"
        "google_assistant"
        "google_cloud"
      ])
      (map ({ platform, ... }: platform) cfg.config.media_player or [ ])
      (map ({ platform, ... }: platform) cfg.config.tts or [ ])
    ];
  };
}
