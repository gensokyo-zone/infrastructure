let
  monitoringModule = {
    nixosConfig,
    config,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
    inherit (lib.lists) elem;
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault mapOptionDefaults unmerged domain;
    inherit (nixosConfig.gensokyo-zone) access;
  in {
    options = with lib.types; {
      enable = mkEnableOption "monitoring";
      systemName = mkOption {
        type = str;
        default = nixosConfig.networking.hostName;
      };
      node = {
        enable =
          mkEnableOption "prometheus.exporters.node"
          // {
            default = true;
          };
        defaultCollectors =
          mkEnableOption "standard node info"
          // {
            default = true;
          };
        settings = mkOption {
          type = unmerged.types.attrs;
          internal = true;
        };
      };
      promtail = {
        enable = mkEnableOption "promtail";
        lokiUrl = mkOption {
          type = str;
        };
        journald = {
          enable =
            mkEnableOption "systemd-journald"
            // {
              default = true;
            };
          settings = mkOption {
            type = unmerged.types.attrs;
            internal = true;
          };
        };
        settings = mkOption {
          type = unmerged.types.attrs;
          internal = true;
        };
      };
    };
    config = {
      node.settings = let
        cfg = config.node;
      in {
        enable = mkDefault true;
        port = mkDefault 9091;
        extraFlags = ["--collector.disable-defaults"];
        enabledCollectors = mkIf cfg.defaultCollectors (mkMerge [
          [
            "systemd"
            "logind"
            "arp"
            "cpu"
            "entropy"
            "filesystem"
            "netdev"
            "ethtool"
            "sysctl"
            "loadavg"
            "meminfo"
            "os"
            "stat"
            "time"
            "uname"
            "vmstat"
          ]
          (mkIf nixosConfig.boot.supportedFilesystems.btrfs or false [
            "btrfs"
          ])
          (mkIf nixosConfig.boot.supportedFilesystems.xfs or false [
            "xfs"
          ])
          (mkIf nixosConfig.boot.supportedFilesystems.zfs or false [
            "zfs"
          ])
          (mkIf nixosConfig.boot.supportedFilesystems.nfs or nixosConfig.boot.supportedFilesystems.nfs4 or false [
            "nfs"
          ])
          (mkIf (!nixosConfig.boot.isContainer) [
            "cpufreq"
            "diskstats"
            "dmi"
            "nvme"
            "hwmon"
          ])
          (mkIf (nixosConfig.services.xserver.enable && elem "amdgpu" nixosConfig.services.xserver.videoDrivers) [
            "drm"
          ])
          (mkIf (nixosConfig.networking.wireless.enable || nixosConfig.networking.wireless.iwd.enable || nixosConfig.networking.networkmanager.enable) [
            "wifi"
          ])
          (mkIf nixosConfig.powerManagement.enable [
            "thermal_zone"
            "powersupplyclass"
            "rapl"
          ])
        ]);
      };
      promtail = let
        cfg = config.promtail;
      in {
        lokiUrl = mkMerge [
          (mkIf access.local.enable (mkDefault "logs.local.${domain}"))
          (mkIf access.tail.enabled (mkAlmostOptionDefault "logs.tail.${domain}"))
          (mkOptionDefault (lib.warn "gensokyo-zone.monitoring: promtail needs lan or tailscale access to function" "logs.${domain}"))
        ];
        journald.settings = {
          job_name = "${config.systemName}-journald";
          journal = {
            max_age = mkOptionDefault "${toString (24 * 7)}h";
            labels = mapOptionDefaults {
              job = "systemd-journald";
              system = config.systemName;
              host = nixosConfig.networking.fqdn;
            };
          };
          relabel_configs = [
            {
              source_labels = ["__journal__systemd_unit"];
              target_label = "unit";
            }
          ];
        };
        settings = {
          enable = mkDefault true;
          configuration = {
            clients = mkOptionDefault [
              {
                url = "${cfg.lokiUrl}/loki/api/v1/push";
              }
            ];
            scrape_configs = mkIf cfg.journald.enable [(unmerged.mergeAttrs cfg.journald.settings)];
          };
        };
      };
    };
  };
in
  {
    config,
    lib,
    gensokyo-zone,
    ...
  }: let
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf;
    inherit (gensokyo-zone.lib) unmerged;
    cfg = config.gensokyo-zone.monitoring;
  in {
    imports = [
      ./access.nix
    ];

    options.gensokyo-zone.monitoring = mkOption {
      type = lib.types.submoduleWith {
        modules = [monitoringModule];
        specialArgs = {
          inherit gensokyo-zone;
          inherit (gensokyo-zone) inputs;
          nixosConfig = config;
        };
      };
      default = {};
    };

    config = {
      services.promtail = mkIf (cfg.enable && cfg.promtail.enable) (
        unmerged.mergeAttrs cfg.promtail.settings
      );
      services.prometheus.exporters = mkIf cfg.enable {
        node = mkIf cfg.node.enable (
          unmerged.mergeAttrs cfg.node.settings
        );
      };

      lib.gensokyo-zone.monitoring = {
        inherit cfg monitoringModule;
      };
    };
  }
