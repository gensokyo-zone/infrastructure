{
  config,
  systemConfig,
  access,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption mkPackageOption;
  inherit (lib.modules) mkIf mkDefault mkMerge;
  cfg = config.gensokyo-zone.netboot;
  nfsEnabled = config.boot.initrd.supportedFilesystems.nfs or config.boot.initrd.supportedFilesystems.nfs4 or false;
  defaultCacheTimeoutMax = 60 * 60; # 1h
  defaultCacheTimeoutMin = 60; # 1m
in {
  options.gensokyo-zone.netboot = with lib.types; {
    # TODO: default = true;
    boot.enable = mkEnableOption "nfs /boot";
    nfs = {
      package = mkPackageOption pkgs "nfs-utils" {
        example = "pkgs.mkinitcpio-nfs-utils";
      };
      security = mkOption {
        type = str;
        default = "sys";
      };
      flags = mkOption {
        type = listOf str;
        default = [
          "nolock" # required in order to mount in initrd when statd daemon isn't running
          "nocto"
          "lazytime" "noatime"
          "actimeo=${toString defaultCacheTimeoutMax}"
          "acregmin=${toString defaultCacheTimeoutMin}"
          "acdirmin=${toString defaultCacheTimeoutMin}"
        ];
      };
    };
  };
  config = {
    boot = {
      initrd = {
        network = {
          enable = mkDefault true;
          ssh = {
            # TODO: enable = true;
          };
        };
        availableKernelModules = mkIf nfsEnabled [
          "nfsv4" "nfsv3"
        ];
        extraUtilsCommands = mkIf (nfsEnabled && !config.boot.initrd.systemd.enable) ''
          copy_bin_and_libs ${cfg.nfs.package}/sbin/mount.nfs
        '';
        systemd = {
          enable = mkDefault true;
          emergencyAccess = mkDefault true;
          initrdBin = mkMerge [
            (mkIf nfsEnabled [cfg.nfs.package])
            (mkIf config.boot.initrd.network.enable [
              pkgs.iproute2
            ])
            [ pkgs.util-linux pkgs.gnugrep ]
          ];
          network = mkIf config.networking.useNetworkd {
            enable = mkDefault true;
          };
        };
      };
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = false;
      };
    };
    fileSystems = let
      nfsUrl = access.proxyUrlFor {
        serviceName = "nfs";
        scheme = "";
        defaultPort = 2049;
        # XXX: consider using dns hostname here instead? (does this require the dns_resolver kernel module?)
        getAddressFor = "getAddress4For";
      } + ":/srv/fs/kyuuto/systems/${systemConfig.name}";
      nfsOpts = [
        "sec=${cfg.nfs.security}"
      ] ++ cfg.nfs.flags;
    in {
      "/" = {
        device = "${nfsUrl}/root";
        fsType = "nfs";
        options = nfsOpts;
      };
      "/boot" = mkIf cfg.boot.enable {
        device = "${nfsUrl}/boot";
        fsType = "nfs";
        options = nfsOpts;
      };
    };
  };
}
