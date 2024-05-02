{
  inputs,
  tree,
  systems,
}: let
  nixlib = inputs.nixpkgs.lib;
  inherit (nixlib.modules) mkOrder mkOverride defaultOverridePriority;
  inherit (nixlib.attrsets) mapAttrs listToAttrs;
  inherit (inputs.self.lib.Std) List Str Regex UInt Opt;

  eui64 = mac: let
    parts = List.map Str.toLower (Regex.splitOn ":" mac);
    part = List.index parts;
    part0 = part: let
      nibble1' = UInt.FromHexDigit (Str.index part 1);
      nibble1 = UInt.or' 2 nibble1';
      nibble0 = Str.index part 0;
    in
      nibble0 + UInt.toHexLower nibble1;
  in "${part0 (part 0)}${part 1}:${part 2}ff:fe${part 3}:${part 4}${part 5}";

  parseUrl = url: let
    parts' = Regex.match ''^([^:]+)://(\[[0-9a-fA-F:]+]|[^/:\[]+)(|:[0-9]+)(|/.*)$'' url;
    parts = parts'.value;
    port' = List.index parts 2;
  in assert Opt.isJust parts'; rec {
    inherit url parts;
    scheme = List.index parts 0;
    host = List.index parts 1;
    port = if port' != "" then UInt.Parse (Str.removePrefix ":" port') else null;
    hostport = host + port';
    path = List.index parts 3;
  };

  userIs = group: user: builtins.elem group (user.extraGroups ++ [user.group]);

  mkWinPath = Str.replace ["/"] ["\\"];
  mkBaseDn = domain: Str.concatMapSep "," (part: "dc=${part}") (Regex.splitOn "\\." domain);
  mkAddress6 = addr: if Str.hasInfix ":" addr && ! Str.hasPrefix "[" addr then "[${addr}]" else addr;

  coalesce = values: Opt.default null (List.find (v: v != null) values);
  mapListToAttrs = f: l: listToAttrs (map f l);

  overrideOptionDefault = 1500;
  overrideAlmostOptionDefault = 1400;
  overrideDefault = 1000;
  overrideAlmostDefault = 900;
  overrideNone = defaultOverridePriority; # 100
  overrideAlmostForce = 75;
  overrideForce = 50;
  overrideVM = 10;
  mkAlmostOptionDefault = mkOverride overrideAlmostOptionDefault;
  mkAlmostDefault = mkOverride overrideAlmostDefault;
  mkAlmostForce = mkOverride overrideAlmostForce;
  orderJustBefore = 400;
  orderBefore = 500;
  orderAlmostBefore = 600;
  orderNone = 1000;
  orderAlmostAfter = 1400;
  orderAfter = 1500;
  orderJustAfter = 1600;
  mkJustBefore = mkOrder orderJustBefore;
  mkAlmostBefore = mkOrder orderAlmostBefore;
  mkAlmostAfter = mkOrder orderAlmostAfter;
  mkJustAfter = mkOrder orderJustAfter;
  mapOverride = priority: mapAttrs (_: mkOverride priority);
  mapOptionDefaults = mapOverride overrideOptionDefault;
  mapAlmostOptionDefaults = mapOverride overrideAlmostOptionDefault;
  mapDefaults = mapOverride overrideDefault;

  treeToModulesOutput = modules:
    {
      ${
        if modules ? __functor
        then "default"
        else null
      } =
        modules.__functor modules;
    }
    // builtins.removeAttrs modules ["__functor"];
in {
  inherit tree nixlib inputs systems;
  meta = tree.impure;
  std = inputs.self.lib.Std.Std.compat;
  Std = inputs.std-fl.lib;
  lib = {
    domain = "gensokyo.zone";
    inherit treeToModulesOutput userIs
      eui64 parseUrl mkWinPath mkBaseDn mkAddress6
      mapListToAttrs coalesce
      mkAlmostOptionDefault mkAlmostDefault mkAlmostForce mapOverride mapOptionDefaults mapAlmostOptionDefaults mapDefaults
      overrideOptionDefault overrideAlmostOptionDefault overrideDefault overrideAlmostDefault overrideNone overrideAlmostForce overrideForce overrideVM
      orderJustBefore orderBefore orderAlmostBefore orderNone orderAfter orderAlmostAfter orderJustAfter
      mkJustBefore mkAlmostBefore mkAlmostAfter mkJustAfter;
    inherit (inputs.arcexprs.lib) unmerged json;
  };
  gensokyo-zone = {
    inherit inputs;
    inherit (inputs) self;
    inherit (inputs.self) overlays;
    inherit (inputs.self.lib) tree meta lib systems std Std;
  };
  generate = import ./generate.nix {inherit inputs tree;};
}
