{
  config,
  options,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault;
  inherit (lib.attrsets) mapAttrsToList mapAttrs' nameValuePair;
  inherit (lib.strings) concatStringsSep;
  inherit (config) networking;
  cfg = config.networking.access.peeps;
  mkSopsName = name: "access-peeps-nft-${name}";
  mkNftName = name: "peeps_${name}6";
  hasSops = options ? sops.secrets;
in {
  options.networking.access.peeps = with lib.types; {
    enable = mkEnableOption "peeps" // {default = hasSops;};
    ranges = mkOption {
      type = attrsOf str;
      default = {};
    };
    stateDir = mkOption {
      type = path;
      default = "/run/access/peeps";
    };
  };
  config.${
    if hasSops
    then "sops"
    else null
  }.secrets = let
    sopsFile = mkDefault ../../../nixos/secrets/access.yaml;
    sopsSecrets = mapAttrs' (name: _:
      nameValuePair (mkSopsName name) {
        inherit sopsFile;
        path = mkDefault "${cfg.stateDir}/${name}.nft";
      })
    cfg.ranges;
  in
    mkIf cfg.enable sopsSecrets;

  config.networking = let
    nftRanges = mapAttrsToList (name: range: let
      nft = "define ${mkNftName name} = ${range}";
    in
      mkBefore nft)
    cfg.ranges;
    condition = "ip6 saddr { ${concatStringsSep "," (mapAttrsToList (name: _: "$" + mkNftName name) cfg.ranges)} }";
  in {
    nftables.ruleset = mkIf cfg.enable (mkMerge (
      nftRanges
      ++ [(mkBefore ''include "${cfg.stateDir}/*.nft"'')]
    ));
    firewall.interfaces.peeps = {
      nftables.enable = cfg.enable;
      nftables.conditions = [
        (mkIf (cfg.enable && networking.enableIPv6) condition)
      ];
    };
  };
}
