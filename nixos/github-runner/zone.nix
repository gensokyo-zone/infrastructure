{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.attrsets) listToAttrs nameValuePair;
  inherit (lib.lists) genList;
  inherit (inputs.self.lib.lib) unmerged;
  cfg = config.services.github-runner-zone;
in {
  options.services.github-runner-zone = with lib.types; {
    enable = mkEnableOption "github-runners.zone" // {
      default = true;
    };
    count = mkOption {
      type = int;
      default = 4;
    };
    user = mkOption {
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
        extraLabels = [ "ubuntu-latest" ];
        tokenFile = mkDefault config.sops.secrets.github-runner-gensokyo-zone-token.path;
        url = mkDefault "https://github.com/gensokyo-zone";
        user = mkDefault cfg.user;
        extraEnvironment = {
          GIT_TEXTDOMAINDIR = "${config.programs.git.package}/share/locale";
        };
      };
    };

    services.github-runners = listToAttrs (genList (i: nameValuePair "zone-${toString i}" (mkMerge [
      (unmerged.merge cfg.runnerSettings)
      {
        name = mkDefault "${config.networking.hostName}-${toString i}";
      }
    ])) cfg.count);

    users = mkIf (cfg.enable && cfg.user != null) {
      users.${cfg.user} = {
        group = cfg.user;
        isSystemUser = true;
      };
      groups.${cfg.user} = { };
    };

    sops.secrets = {
      github-runner-gensokyo-zone-token = mkIf cfg.enable {
        sopsFile = mkDefault ../secrets/github-runner.yaml;
        owner = mkIf (cfg.user != null) cfg.user;
      };
    };
  };
}
