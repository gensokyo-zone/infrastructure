{
  config,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostForce;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) genAttrs;
  cfg = config.services.sssd;
  pamRulesModule = { ... }: let
    rules = [ "account" "auth" "password" "session" ];
    mkRuleConfig = ruleName: {
      sss = mkIf cfg.enable {
        enable = mkIf (!cfg.services.pam.enable) (mkAlmostForce false);
      };
    };
  in {
    config = genAttrs rules mkRuleConfig;
  };
  pamServiceModule = { ... }: {
    options = with lib.types; {
      rules = mkOption {
        type = submodule pamRulesModule;
      };
    };
  };
in {
  options.security.pam = with lib.types; {
    services = mkOption {
      type = attrsOf (submodule pamServiceModule);
    };
  };
}
