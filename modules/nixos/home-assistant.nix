{
  pkgs,
  config,
  access,
  lib,
  ...
}: let
  cfg = config.services.home-assistant;
  inherit (lib.modules) mkIf mkMerge mkBefore mkAfter mkDefault mkOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.lists) optional elem unique;
  inherit (lib.strings) toLower;
in {
  options.services.home-assistant = with lib.types; {
    mutableUiConfig = mkEnableOption "UI-editable config files";
    domain = mkOption {
      type = str;
      default = config.networking.domain;
    };
    localDomain = mkOption {
      type = nullOr str;
      default = null;
    };
    secretsFile = mkOption {
      type = nullOr path;
      default = null;
    };
    reverseProxy = {
      enable = mkEnableOption "use_x_forwarded_for";
      trustedAddresses = mkOption {
        type = listOf str;
      };
      auth = {
        enable = mkEnableOption "auth-header";
        debug = mkEnableOption "debug logging";
        userHeader = mkOption {
          type = str;
        };
      };
    };
    homekit = {
      enable =
        mkEnableOption "homekit"
        // {
          default = cfg.config.homekit or [] != [];
        };
      openFirewall =
        mkEnableOption "homekit ports"
        // {
          default = cfg.openFirewall;
        };
    };
    googleAssistant.enable =
      mkEnableOption "Google Assistant"
      // {
        default = cfg.config.google_assistant or {} != {};
      };
    androidTv.enable =
      mkEnableOption "Android TV"
      // {
        default = elem "androidtv" cfg.extraComponents;
      };
    grocy.enable = mkEnableOption "Grocy custom component";
    brother.enable =
      mkEnableOption "brother"
      // {
        default = elem "brother" cfg.extraComponents;
      };
    cast = {
      enable =
        mkEnableOption "Chromecast"
        // {
          default = elem "cast" cfg.extraComponents;
        };
      openFirewall =
        mkEnableOption "Chromecast ports"
        // {
          default = cfg.openFirewall;
        };
    };
    finalPackage = mkOption {
      type = types.path;
      readOnly = true;
    };
  };

  config = {
    networking.firewall = let
      homekitTcp = mkIf cfg.homekit.enable (
        map ({port, ...}: port) cfg.config.homekit or []
      );

      castUdpRanges = mkIf cfg.cast.enable [
        {
          from = 32768;
          to = 60999;
        }
      ];
    in
      mkIf cfg.enable {
        interfaces.local = {
          allowedTCPPorts = mkMerge [
            (mkIf (!cfg.homekit.openFirewall) homekitTcp)
            (mkIf (!cfg.openFirewall && !cfg.reverseProxy.enable) [cfg.config.http.server_port])
          ];
          allowedUDPPortRanges = mkIf (!cfg.cast.openFirewall) castUdpRanges;
        };
        interfaces.lan = {
          allowedTCPPorts = mkIf (!cfg.openFirewall && cfg.reverseProxy.enable) [
            cfg.config.http.server_port
          ];
        };
        allowedTCPPorts = mkIf cfg.homekit.openFirewall homekitTcp;
        allowedUDPPortRanges = mkIf cfg.cast.openFirewall castUdpRanges;
      };

    # MDNS
    services.avahi = mkIf (cfg.enable && cfg.homekit.enable) {
      enable = mkDefault true;
      publish.enable = let
        homekitNames = map (homekit: toLower homekit.name) cfg.config.homekit or [];
      in
        mkIf (elem config.networking.hostName homekitNames) false;
    };

    systemd.services.home-assistant = mkIf (cfg.enable && cfg.mutableUiConfig) {
      # UI-editable config files
      preStart = mkMerge [
        (mkBefore ''
          touch "${cfg.configDir}/"{automations,scenes,scripts,manual,homekit_entity_config,homekit_include_entities}.yaml
        '')
        (mkIf (cfg.secretsFile != null) (mkBefore ''
          ln -sf ${cfg.secretsFile} "${cfg.configDir}/secrets.yaml"
        ''))
      ];
    };
  };

  config.services.home-assistant = {
    reverseProxy = {
      trustedAddresses = access.cidrForNetwork.loopback.all;
    };
    config = mkMerge [
      {
        homeassistant = {
          external_url = "https://${cfg.domain}";
          internal_url = mkIf (cfg.localDomain != null) "https://${cfg.localDomain}";
        };
        logger = {
          default = mkDefault "info";
          logs = {
            "custom_components.auth_header" = mkIf (cfg.reverseProxy.enable && cfg.reverseProxy.auth.enable && cfg.reverseProxy.auth.debug) "debug";
          };
        };
        http = {
          use_x_forwarded_for = cfg.reverseProxy.enable;
          trusted_proxies = mkIf cfg.reverseProxy.enable cfg.reverseProxy.trustedAddresses;
          cors_allowed_origins = [
            (mkIf cfg.googleAssistant.enable "https://google.com")
            (mkIf cfg.cast.enable "https://cast.home-assistant.io")
            (mkIf (cfg.localDomain != null) "https://${cfg.localDomain}")
            # TODO: (mkIf (cfg.reverseProxy.enable && cfg.reverseProxy.auth.enable) vouch cors idk)
            "https://www.home-assistant.io"
          ];
        };
        auth_header = mkIf (cfg.reverseProxy.enable && cfg.reverseProxy.auth.enable) {
          username_header = cfg.reverseProxy.auth.userHeader;
          debug = mkIf cfg.reverseProxy.auth.debug true;
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
      # https://github.com/pysnmp/pysnmp/issues/51
      needsPyasn1pin =
        if lib.versionOlder python.pkgs.pysnmplib.version "6.0"
        then true
        else lib.warn "pyasn1 pin likely no longer needed" false;
      pyasn1prefix = "${python.pkgs.pysnmp-pyasn1}/${python.sitePackages}";
      home-assistant = pkgs.home-assistant.override {
        packageOverrides = self: super: {
          brother = super.brother.overridePythonAttrs (old: {
            dontCheckRuntimeDeps =
              if old.dontCheckRuntimeDeps or false
              then lib.warn "brother override no longer needed" true
              else true;
          });
          mpd2 = super.mpd2.overridePythonAttrs (old: {
            patches =
              old.patches
              or []
              ++ [
                ../../packages/mpd2-skip-flaky-test.patch
              ];
            disabledTests = unique (old.disabledTests
              or []
              ++ [
                "test_idle_timeout"
              ]);
          });
          env-canada = super.env-canada.overridePythonAttrs (old: {
            dependencies =
              old.dependencies
              ++ [
                self.defusedxml
              ];
          });
        };
      };
    in
      home-assistant.overrideAttrs (old: {
        makeWrapperArgs = old.makeWrapperArgs ++ optional (cfg.brother.enable && needsPyasn1pin) "--prefix PYTHONPATH : ${pyasn1prefix}";
        disabledTests = unique (old.disabledTests
          or []
          ++ [
            "test_check_config"
          ]);
      });
    finalPackage = let
      inherit (lib.strings) hasSuffix removeSuffix splitString;
      inherit (lib.lists) head;
      inherit (lib.attrsets) attrNames filterAttrs;
      inherit (config.systemd.services.home-assistant.serviceConfig) ExecStart;
      isHassDrv = drv: context: hasSuffix "-${cfg.package.name}.drv" drv && context.outputs or [] == ["out"];
      drvs = filterAttrs isHassDrv (builtins.getContext ExecStart);
      isImpure = builtins ? currentSystem;
    in
      mkIf cfg.enable (mkOptionDefault (
        if isImpure
        then import (head (attrNames drvs))
        else removeSuffix "/bin/hass" (head (splitString " " ExecStart))
      ));
    extraPackages = python3Packages:
      with python3Packages;
        mkMerge [
          [
            psycopg2
            securetar
            getmac # for upnp integration
            python-otbr-api
            (aiogithubapi.overrideAttrs (_: {doInstallCheck = false;}))
          ]
          (mkIf cfg.homekit.enable [
            aiohomekit
          ])
          (mkIf cfg.androidTv.enable [
            adb-shell
            androidtvremote2
          ])
          (mkIf cfg.grocy.enable [
            (python3Packages.callPackage ../../packages/grocy/pygrocy.nix {})
          ])
          (mkIf (elem "discord" cfg.extraComponents) [
            setuptools
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
        "ios"
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
      (map ({platform, ...}: platform) cfg.config.media_player or [])
      (map ({platform, ...}: platform) cfg.config.tts or [])
    ];
    customComponents = [
      (
        mkIf (cfg.reverseProxy.enable && cfg.reverseProxy.auth.enable)
        pkgs.home-assistant-custom-components.auth-header
      )
    ];
  };
  config.users.users.hass = mkIf cfg.enable {
    extraGroups = mkIf (elem "androidtv" cfg.extraComponents && (config.programs.adb.enable || config.services.adb.enable)) [
      "adbusers"
    ];
  };
}
