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
            (mkIf config.nfs.enable "nfs.${config.domain}:/mnt/kyuuto-media")
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
            (mkIf config.nfs.enable "nfs.${config.domain}:/mnt/kyuuto-media/transfer")
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
    lib.gensokyo-zone.kyuuto = {
      inherit cfg kyuutoModule;
    };
  };
}
