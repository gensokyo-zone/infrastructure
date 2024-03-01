{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib.lib) unmerged;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.strings) match concatStringsSep escapeShellArg optionalString;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) filter;
  isGroupWritable = mode: match "[234567][0-7][76][0-7]" mode != null;
  isOtherWritable = mode: match "[0-7][0-7][0-7][76]" mode != null;
  cfg = config.services.tmpfiles;
  files = filter (file: file.enable) (attrValues cfg.files);
  systemdFiles = filter (file: file.systemd.enable) files;
  setupFiles = filter (file: !file.systemd.enable) files;
  bindFiles = filter (file: file.type == "bind") files;
  fileModule = { config, name, ... }: {
    options = with lib.types; {
      enable = mkEnableOption "file" // {
        default = true;
      };
      mkdirParent = mkEnableOption "mkdir";
      bindReadOnly = mkEnableOption "mount -oro";
      relativeSymlink = mkEnableOption "ln -sr";
      noOverwrite = mkEnableOption "disable overwrite";
      path = mkOption {
        type = path;
        default = name;
      };
      type = mkOption {
        type = enum [ "directory" "symlink" "link" "copy" "bind" ];
        default = if config.src != null then "symlink" else "directory";
      };
      mode = mkOption {
        type = str;
        default = "0755";
      };
      owner = mkOption {
        type = str;
        default = cfg.user;
      };
      group = mkOption {
        type = str;
        default = "root";
      };
      src = mkOption {
        type = nullOr path;
        default = null;
      };
      acls = mkOption {
        type = listOf str;
      };
      systemd = {
        enable = mkEnableOption "systemd-tmpfiles";
        rules = mkOption {
          type = listOf str;
        };
        mountSettings = mkOption {
          type = unmerged.type;
        };
      };
      setup = {
        script = mkOption {
          type = lines;
        };
      };
    };
    config = let
      acls = concatStringsSep "," config.acls;
      enableAcls = config.type == "directory" && config.acls != [ ];
      systemdAclRule = "a+ ${config.path} - - - - ${acls}";
      systemdRule = {
        directory = [
          "d ${config.path} ${config.mode} ${config.owner} ${config.group}"
        ];
        symlink = [
          "L+ ${config.path} - - - - ${config.src}"
        ];
        copy = [
          "C ${config.path} - - - - ${config.src}"
          "z ${config.path} ${config.mode} ${config.owner} ${config.group} - ${config.src}"
        ];
        link = throw "unsupported link for systemd tmpfiles";
        bind = throw "unsupported bind for systemd tmpfiles";
      };
      chown = "chown ${escapeShellArg config.owner}:${escapeShellArg config.group} ${escapeShellArg config.path}";
      chmod = "chmod ${escapeShellArg config.mode} ${escapeShellArg config.path}";
      parentFlag = optionalString config.mkdirParent "p";
      relativeFlag = optionalString config.relativeSymlink "r";
      scriptCatch = " || EXITCODE=$?";
      scriptFail = "EXITCODE=1";
      setupScript = {
        directory = ''
          if [[ -d ${escapeShellArg config.path} ]]; then
            ${chmod} &&
            ${chown}${scriptCatch}
          elif [[ ! -e ${escapeShellArg config.path} ]]; then
            mkdir -${parentFlag}m ${escapeShellArg config.mode} ${escapeShellArg config.path} &&
            ${chown}${scriptCatch}
          else
            echo ${escapeShellArg config.path} exists but is not a directory >&2
            ${scriptFail}
          fi
        '';
        symlink = ''
          if [[ -e ${escapeShellArg config.path} && ! -L ${escapeShellArg config.path} ]]; then
            echo ${escapeShellArg config.path} exists but is not a symlink >&2
            ${scriptFail}
          else
            if [[ ! -L ${escapeShellArg config.path} || -z ${escapeShellArg config.noOverwrite} ]]; then
              ln -s${relativeFlag}fT ${escapeShellArg config.src} ${escapeShellArg config.path} &&
              ${chown} -h${scriptCatch}
            fi
          fi
        '';
        link = ''
          if [[ -L ${escapeShellArg config.path} ]]; then
            rm -f ${escapeShellArg config.path}
          fi
          ln -fT ${escapeShellArg config.src} ${escapeShellArg config.path}${scriptCatch}
        '';
        copy = ''
          if [[ -d ${escapeShellArg config.src} ]]; then
            echo TODO: copy directory to ${escapeShellArg config.path} >&2
            ${scriptFail}
          else
            if [[ -L ${escapeShellArg config.path} ]] || [[ -e ${escapeShellArg config.path} && ! -f ${escapeShellArg config.path} ]]; then
              echo ${escapeShellArg config.path} exists but is not a file >&2
              ${scriptFail}
            else
              if [[ ! -e ${escapeShellArg config.path} || -z ${escapeShellArg config.noOverwrite} ]]; then
                cp -TPf ${escapeShellArg config.src} ${escapeShellArg config.path}${scriptCatch}
              fi
              ${chmod} &&
              ${chown}${scriptCatch}
            fi
          fi
        '';
        bind = ''
          if [[ ! -e ${escapeShellArg config.src} ]]; then
            echo ${escapeShellArg config.src} does not exist >&2
            ${scriptFail}
          elif [[ -d $(readlink -f ${escapeShellArg config.src}) ]]; then
            mkdir -p ${escapeShellArg config.path}${scriptCatch}
          else
            if [[ ! -e ${escapeShellArg config.path} ]]; then
              touch ${escapeShellArg config.path}${scriptCatch}
            fi
          fi
        '';
      };
      aclScript = ''
        setfacl -b -m ${escapeShellArg acls} ${escapeShellArg config.path}${scriptCatch}
      '';
    in {
      acls = mkOptionDefault [
        (mkIf (isGroupWritable config.mode) "default:group::rwx")
        (mkIf (isOtherWritable config.mode) "default:other::rwx")
      ];
      setup.script = mkMerge [
        setupScript.${config.type}
        (mkIf enableAcls aclScript)
      ];
      systemd = {
        rules = mkMerge [
          systemdRule.${config.type}
          (mkIf enableAcls [ systemdAclRule ])
        ];
        mountSettings = mkIf (config.type == "bind") {
          enable = mkDefault config.enable;
          type = mkDefault "none";
          options = mkMerge [
            "bind"
            (mkIf config.bindReadOnly "ro")
          ];
          what = mkDefault config.src;
          where = mkDefault config.path;
          wantedBy = [
            "tmpfiles.service"
          ];
          after = mkDefault [
            "tmpfiles.service"
          ];
        };
      };
    };
  };
in {
  options.services.tmpfiles = with lib.types; {
    enable = mkEnableOption "extended tmpfiles" // {
      default = cfg.files != { };
    };
    user = mkOption {
      type = str;
      default = if config.proxmoxLXC.privileged or true then "root" else "admin";
    };
    files = mkOption {
      type = attrsOf (submodule fileModule);
      default = { };
    };
  };
  config = {
    systemd = mkIf cfg.enable {
      tmpfiles.rules = mkMerge (
        map (file: file.systemd.rules) systemdFiles
      );
      services.tmpfiles = {
        path = [ pkgs.coreutils pkgs.acl ];
        script = mkMerge (
          [ ''
            EXITCODE=0
          '' ]
          ++ map (file: file.setup.script) setupFiles
          ++ [ ''
            exit $EXITCODE
          '' ]
        );
        wantedBy = [
          "sysinit.target"
        ];
        after = [
          "local-fs.target"
        ];
        before = [
          "systemd-tmpfiles-setup.service"
          "systemd-tmpfiles-resetup.service"
        ];
        serviceConfig = {
          User = mkOptionDefault cfg.user;
          RemainAfterExit = mkOptionDefault true;
        };
      };
      mounts = map (file: unmerged.merge file.systemd.mountSettings) bindFiles;
    };
  };
}
