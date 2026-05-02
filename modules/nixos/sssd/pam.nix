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
  pamRuleModule = {name, ...}: {
    config.enable = mkIf (name == "sss" && cfg.enable && !cfg.services.pam.enable) (
      mkAlmostForce false
    );
  };
  pamRulesModule = {...}: let
    rules = ["account" "auth" "password" "session"];
    mkRuleConfig = ruleName: mkOption {
      type = with lib.types; attrsOf (submodule pamRuleModule);
    };
  in {
    options = genAttrs rules mkRuleConfig;
  };
  pamServiceModule = {...}: {
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
