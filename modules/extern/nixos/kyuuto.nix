{
  config,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (gensokyo-zone.lib) unmerged;
  cfg = config.gensokyo-zone.kyuuto;
  kyuutoModule = {
    gensokyo-zone,
    nixosConfig,
    config,
    ...
  }: let
    inherit (gensokyo-zone.lib) unmerged domain;
    setFilesystemOptions = mkMerge [
      (mkIf config.nfs.enable config.nfs.fstabOptions)
      (mkIf config.smb.enable config.smb.fstabOptions)
      (mkIf config.automount.enable config.automount.fstabOptions)
    ];
  in {
    options = with lib.types; {
      enable = mkEnableOption "kyuuto";
      media.enable =
        mkEnableOption "/mnt/kyuuto-media"
        // {
          default = true;
        };
      transfer.enable =
        mkEnableOption "/mnt/kyuuto-transfer"
        // {
          default = true;
        };
      shared.enable = mkEnableOption "/mnt/kyuuto-shared";
      domain = mkOption {
        type = str;
      };
      local.enable = mkEnableOption "LAN";
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
      };
    };
    config = {
      domain = mkMerge [
        (mkOptionDefault (
          if config.local.enable
          then "local.${domain}"
          else domain
        ))
        (mkIf nixosConfig.services.tailscale.enable (
          mkDefault
          "tail.${domain}"
        ))
      ];
      nfs.fstabOptions = [
        "noauto"
        "nfsvers=4"
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
            (mkIf config.nfs.enable "nfs.${config.domain}:/mnt/kyuuto-media")
            (mkIf config.smb.enable (
              if config.smb.user != null && config.local.enable
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
          options = setFilesystemOptions;
        };
        "/mnt/kyuuto-transfer" = mkIf config.transfer.enable {
          device = mkMerge [
            (mkIf config.nfs.enable "nfs.${config.domain}:/mnt/kyuuto-media/transfer")
            (mkIf (config.smb.enable && config.local.enable) ''\\smb.${config.domain}\kyuuto-transfer'')
          ];
          fsType = mkMerge [
            (mkIf config.nfs.enable "nfs4")
            (mkIf config.smb.enable "smb3")
          ];
          options = setFilesystemOptions;
        };
        "/mnt/kyuuto-shared" = mkIf (config.shared.enable && config.smb.enable) {
          device = mkIf (config.smb.user != null) ''\\smb.${config.domain}\shared'';
          fsType = "smb3";
          options = setFilesystemOptions;
        };
      };
    };
  };
in {
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
    lib.gensokyo-zone.kyuuto = {
      inherit cfg kyuutoModule;
    };
  };
}
