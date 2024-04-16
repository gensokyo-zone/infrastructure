{
  config,
  lib,
  utils,
  gensokyo-zone,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.lists) optional;
  inherit (lib.strings) concatMapStringsSep;
  inherit (utils) escapeSystemdPath;
  inherit (gensokyo-zone.lib) unmerged;
  cfg = config.gensokyo-zone.kyuuto;
  nfsEnabled = config.boot.supportedFilesystems.nfs or config.boot.supportedFilesystems.nfs4 or false;
  kyuutoModule = {
    gensokyo-zone,
    nixosConfig,
    config,
    ...
  }: let
    inherit (gensokyo-zone.lib) unmerged domain;
    inherit (nixosConfig.gensokyo-zone) access;
    enabled = {
      krb5 = nixosConfig.gensokyo-zone.krb5.enable or false;
    };
    setFilesystemOptions = [
      (mkIf config.nfs.enable config.nfs.fstabOptions)
      (mkIf config.smb.enable config.smb.fstabOptions)
      (mkIf config.automount.enable config.automount.fstabOptions)
    ];
  in {
    options = with lib.types; {
      enable = mkEnableOption "kyuuto";
      media = {
        enable = mkEnableOption "/mnt/kyuuto-media" // {
          default = true;
        };
        krb5.enable = mkEnableOption "krb5" // {
          default = enabled.krb5;
        };
      };
      transfer = {
        enable = mkEnableOption "/mnt/kyuuto-transfer" // {
          default = true;
        };
        krb5.enable = mkEnableOption "krb5" // {
          default = enabled.krb5;
        };
      };
      shared.enable = mkEnableOption "/mnt/kyuuto-shared";
      domain = mkOption {
        type = str;
      };
      automount = {
        enable =
          mkEnableOption "systemd automount"
          // {
            default = true;
          };
        fstabOptions = mkOption {
          type = listOf str;
        };
      };
      nfs = {
        enable =
          mkEnableOption "NFS mounts"
          // {
            default = true;
          };
        fstabOptions = mkOption {
          type = listOf str;
        };
      };
      smb = {
        enable = mkEnableOption "SMB mounts";
        user = mkOption {
          type = nullOr null;
          default = null;
        };
        fstabOptions = mkOption {
          type = listOf str;
        };
      };
      setFilesystems = mkOption {
        type = unmerged.types.attrs;
        internal = true;
      };
      setUnits = mkOption {
        type = unmerged.types.attrs;
        internal = true;
      };
    };
    config = {
      domain = mkMerge [
        (mkOptionDefault (
          if access.local.enable
          then "local.${domain}"
          else domain
        ))
        (mkIf access.tail.enabled (
          mkDefault
          "tail.${domain}"
        ))
      ];
      nfs.fstabOptions = [
        "noauto"
        #"nfsvers=4"
        "soft"
        "retrans=2"
        "timeo=60"
      ];
      smb.fstabOptions = [
        "noauto"
        (mkIf (config.smb.user != null) "user=${config.smb.user}")
      ];
      automount.fstabOptions = [
        "x-systemd.automount"
        "x-systemd.mount-timeout=2m"
        "x-systemd.idle-timeout=10m"
      ];
      setFilesystems = {
        "/mnt/kyuuto-media" = mkIf config.media.enable {
          device = mkMerge [
            (mkIf config.nfs.enable "nfs.${config.domain}:/srv/fs/kyuuto/media")
            (mkIf config.smb.enable (
              if config.smb.user != null && access.local.enable
              then ''\\smb.${config.domain}\kyuuto-media''
              else if config.smb.user != null
              then ''\\smb.${config.domain}\kyuuto-media-global''
              else ''\\smb.${config.domain}\kyuuto-library-access''
            ))
          ];
          fsType = mkMerge [
            (mkIf config.nfs.enable "nfs4")
            (mkIf config.smb.enable "smb3")
          ];
          options = mkMerge (setFilesystemOptions ++ [
            (mkIf config.media.krb5.enable [
              "sec=krb5"
              (mkIf config.nfs.enable "nfsvers=4")
            ])
          ]);
        };
        "/mnt/kyuuto-transfer" = mkIf config.transfer.enable {
          device = mkMerge [
            (mkIf config.nfs.enable "nfs.${config.domain}:/srv/fs/kyuuto/transfer")
            (mkIf (config.smb.enable && access.local.enable) ''\\smb.${config.domain}\kyuuto-transfer'')
          ];
          fsType = mkMerge [
            (mkIf config.nfs.enable "nfs4")
            (mkIf config.smb.enable "smb3")
          ];
          options = mkMerge (setFilesystemOptions ++ [
            (mkIf config.media.krb5.enable [
              (if access.local.enable || access.tail.enabled then "sec=sys:krb5" else "sec=krb5")
              #(mkIf config.nfs.enable "nfsvers=3")
            ])
          ]);
        };
        "/mnt/kyuuto-shared" = mkIf (config.shared.enable && config.smb.enable) {
          device = mkIf (config.smb.user != null) ''\\smb.${config.domain}\shared'';
          fsType = "smb3";
          options = mkMerge setFilesystemOptions;
        };
      };
      setUnits = let
        netMountConfig = {
          overrideStrategy = mkDefault "asDropin";
          text = let
            after =
              optional nixosConfig.systemd.network.enable "systemd-networkd.service"
              ++ optional nixosConfig.networking.networkmanager.enable "NetworkManager.service"
              ++ optional nixosConfig.services.connman.enable "connman.service"
              ++ optional access.tail.enabled "tailscaled.service";
          in ''
            [Unit]
            JobTimeoutSec=30
            ${concatMapStringsSep "\n" (unit: "After=${unit}") after}

            [Mount]
            ForceUnmount=true
            TimeoutSec=30
          '';
        };
      in {
        "${escapeSystemdPath "/mnt/kyuuto-media"}.mount" = mkIf config.media.enable netMountConfig;
        "${escapeSystemdPath "/mnt/kyuuto-transfer"}.mount" = mkIf config.transfer.enable netMountConfig;
        "${escapeSystemdPath "/mnt/kyuuto-shared"}.mount" = mkIf (config.shared.enable && config.smb.enable) netMountConfig;
      };
    };
  };
in {
  imports = [
    ./access.nix
  ];

  options.gensokyo-zone.kyuuto = mkOption {
    type = lib.types.submoduleWith {
      modules = [kyuutoModule];
      specialArgs = {
        inherit gensokyo-zone;
        inherit (gensokyo-zone) inputs;
        nixosConfig = config;
      };
    };
    default = { };
  };

  config = {
    fileSystems = mkIf cfg.enable (
      unmerged.mergeAttrs cfg.setFilesystems
    );
    systemd.services.rpc-svcgssd = mkIf (!config.services.nfs.server.enable && nfsEnabled) {
      enable = false;
    };
    systemd.units = mkIf cfg.enable (
      unmerged.mergeAttrs cfg.setUnits
    );

    lib.gensokyo-zone.kyuuto = {
      inherit cfg kyuutoModule;
    };
  };
}
