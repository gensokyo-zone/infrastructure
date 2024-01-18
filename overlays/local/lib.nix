lib: prev: let
  inherit (lib.strings) splitString toLower;
  inherit (lib.lists) imap0 elemAt;
  inherit (lib.attrsets) listToAttrs nameValuePair;
  inherit (lib.strings) substring fixedWidthString;
  inherit (lib.trivial) flip toHexString toHexStringLower hexCharToInt bitOr;
in {
  trivial = prev.trivial // {
    toHexStringLower = v: toLower (toHexString v);

    hexCharToInt = let
      hexChars = [ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f" ];
      pairs = imap0 (flip nameValuePair) hexChars;
      idx = listToAttrs pairs;
    in char: idx.${char};

    eui64 = mac: let
      parts = map toLower (splitString ":" mac);
      part = elemAt parts;
      part0 = part: let
        nibble1' = hexCharToInt (substring 1 1 part);
        nibble1 = bitOr 2 nibble1';
        nibble0 = substring 0 1 part;
      in nibble0 + (fixedWidthString 1 "0" (toHexStringLower nibble1));
    in "${part0 (part 0)}${part 1}:${part 2}ff:fe${part 3}:${part 4}${part 5}";
  };
}
