{
  pkgs,
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.attrsets) listToAttrs nameValuePair;
  inherit (lib.lists) genList;
  inherit (gensokyo-zone.lib) unmerged;
  cfg = config.services.github-runner-zone;
  genZone = f: genList f cfg.count;
  genZoneAttrs = prefix: f: listToAttrs (genZone (i: nameValuePair "${prefix}${toString i}" (f i)));
in {
  options.services.github-runner-zone = with lib.types; {
    enable =
      mkEnableOption "github-runners.zone"
      // {
        default = true;
      };
    targetName = mkOption {
      type = str;
      default = "github-runner-zone";
    };
    networkNamespace.name = mkOption {
      type = nullOr str;
      default = null;
    };
    count = mkOption {
      type = int;
      default = 4;
    };
    ephemeral = mkOption {
      type = bool;
      default = true;
    };
    keyPrefix = mkOption {
      type = str;
      default = "zone-";
    };
    namePrefix = mkOption {
      type = str;
      default = "${config.networking.hostName}-";
    };
    userPrefix = mkOption {
      type = nullOr str;
      default = "github-runner-zone-";
    };
    dynamicUser = mkOption {
      type = bool;
      default = false;
    };
    group = mkOption {
      type = nullOr str;
      default = "github-runner-zone";
    };
    runnerSettings = mkOption {
      type = unmerged.type;
    };
  };

  config = {
    services.github-runner-zone = {
      runnerSettings = {
        enable = mkDefault true;
        ephemeral = mkDefault cfg.ephemeral;
        replace = mkDefault true;
        extraLabels = ["ubuntu-latest"];
        tokenFile = mkDefault config.sops.secrets.github-runner-gensokyo-zone-token.path;
        url = mkDefault "https://github.com/gensokyo-zone";
        group = mkDefault cfg.group;
        extraEnvironment = {
          GIT_TEXTDOMAINDIR = "${config.programs.git.package}/share/locale";
        };
        extraPackages = with pkgs; [
          rsync
          zip
          curl
        ];
        networkNamespace.name = mkIf (cfg.networkNamespace.name != null) (mkDefault cfg.networkNamespace.name);
        serviceSettings = {
          wantedBy = ["${cfg.targetName}.target"];
          unitConfig = {
            StopPropagatedFrom = ["${cfg.targetName}.target"];
          };
          serviceConfig = {
            Nice = mkDefault 5;
          };
        };
        serviceOverrides = mkIf (!cfg.dynamicUser) {
          # XXX: the ci sshd hack requires this for now :<
          PrivateUsers = false;
          InaccessiblePaths = [
            "/run/wrappers"
          ];
        };
      };
    };

    services.github-runners = mkIf cfg.enable (genZoneAttrs cfg.keyPrefix (i:
      mkMerge [
        (unmerged.merge cfg.runnerSettings)
        {
          name = mkDefault "${cfg.namePrefix}${toString i}";
          user = mkIf (cfg.userPrefix != null) (
            mkDefault "${cfg.userPrefix}${toString i}"
          );
        }
      ]));

    systemd = mkIf cfg.enable {
      services.nix-daemon = mkIf cfg.enable {
        networkNamespace = mkIf (cfg.networkNamespace.name != null) {
          name = mkDefault cfg.networkNamespace.name;
          privateMounts = mkDefault false;
        };
      };
      targets.${cfg.targetName} = {
        wantedBy = ["multi-user.target"];
      };
    };

    users = mkIf cfg.enable {
      groups = mkIf (cfg.group != null) {
        ${toString cfg.group} = {};
      };
      users = mkMerge [
        (mkIf (!cfg.dynamicUser) (genZoneAttrs cfg.userPrefix (i: {
          isSystemUser = true;
          useDefaultShell = mkDefault true;
          group = mkIf (cfg.group != null) (mkDefault cfg.group);
          extraGroups = [
            "nixbuilder"
          ];
          createHome = false;
          home = "/var/lib/github-runner/${cfg.keyPrefix}${toString i}";
        })))
      ];
    };

    sops.secrets = {
      github-runner-gensokyo-zone-token = mkIf cfg.enable {
        sopsFile = mkDefault ../secrets/github-runner.yaml;
      };
    };
  };
}
