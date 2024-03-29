{
  inputs,
  tree,
  systems,
}: let
  nixlib = inputs.nixpkgs.lib;
  inherit (nixlib.modules) mkOrder mkOverride;
  inherit (nixlib.strings) splitString toLower;
  inherit (nixlib.lists) imap0 elemAt;
  inherit (nixlib.attrsets) mapAttrs listToAttrs nameValuePair;
  inherit (nixlib.strings) substring fixedWidthString replaceStrings concatMapStringsSep;
  inherit (nixlib.trivial) flip toHexString bitOr;

  toHexStringLower = v: toLower (toHexString v);

  hexCharToInt = let
    hexChars = ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f"];
    pairs = imap0 (flip nameValuePair) hexChars;
    idx = listToAttrs pairs;
  in
    char: idx.${char};

  eui64 = mac: let
    parts = map toLower (splitString ":" mac);
    part = elemAt parts;
    part0 = part: let
      nibble1' = hexCharToInt (substring 1 1 part);
      nibble1 = bitOr 2 nibble1';
      nibble0 = substring 0 1 part;
    in
      nibble0 + (fixedWidthString 1 "0" (toHexStringLower nibble1));
  in "${part0 (part 0)}${part 1}:${part 2}ff:fe${part 3}:${part 4}${part 5}";

  userIs = group: user: builtins.elem group (user.extraGroups ++ [user.group]);

  mkWinPath = replaceStrings ["/"] ["\\"];
  mkBaseDn = domain: concatMapStringsSep "," (part: "dc=${part}") (splitString "." domain);

  mapListToAttrs = f: l: listToAttrs (map f l);

  mkAlmostOptionDefault = mkOverride 1400;
  mkAlmostAfter = mkOrder 1400;
  mapOverride = priority: mapAttrs (_: mkOverride priority);
  mapOptionDefaults = mapOverride 1500;

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
    inherit treeToModulesOutput mkWinPath mkBaseDn userIs eui64 toHexStringLower hexCharToInt;
    inherit mkAlmostAfter mkAlmostOptionDefault mapOptionDefaults mapOverride mapListToAttrs;
    inherit (inputs.arcexprs.lib) unmerged json;
  };
  generate = import ./generate.nix {inherit inputs tree;};
}
