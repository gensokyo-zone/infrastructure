{
  config,
  system,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostForce;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.attrsets) optionalAttrs;
  inherit (gensokyo-zone.self) overlays;
  cfg = config.nixpkgs;
  hostPlatform = lib.systems.elaborate {
    inherit (system) system;
  };
in {
  options.nixpkgs = with lib.types; {
    usePkgs = mkOption {
      type = enum ["legacyPackages.pkgs" "import" "nixos"];
      description = "gensokyo-zone#legacyPackages.pkgs";
      default =
        if cfg.buildPlatform == cfg.hostPlatform && cfg.hostPlatform == hostPlatform && gensokyo-zone.self ? legacyPackages.${cfg.hostPlatform.system}.pkgs
        then "legacyPackages.pkgs"
        else "import";
    };
  };
  config.nixpkgs = {
    hostPlatform = mkDefault hostPlatform;
    overlays = [
      gensokyo-zone.inputs.arcexprs.overlays.default
      overlays.default
    ];
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
  };
  config._module.args.pkgs = let
    pkgsArgs = {
      inherit (cfg) config overlays;
      localSystem = cfg.buildPlatform;
    };
    pkgsCrossArgs = optionalAttrs (cfg.buildPlatform != cfg.hostPlatform) {
      crossSystem = cfg.hostPlatform;
    };
    pkgs = {
      "legacyPackages.pkgs" = gensokyo-zone.self.legacyPackages.${cfg.hostPlatform.system}.pkgs;
      import = import gensokyo-zone.inputs.nixpkgs (pkgsArgs // pkgsCrossArgs);
    };
  in
    mkIf (cfg.usePkgs != "nixos") (mkAlmostForce pkgs.${cfg.usePkgs}.__withSubBuilders);
}
