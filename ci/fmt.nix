{
  nix = {
    whitelist = [
      "systems/mediabox/nixos.nix"
    ];
    blacklistDirs = [
      "overlays"
      "ci"
    ];
  };
}
