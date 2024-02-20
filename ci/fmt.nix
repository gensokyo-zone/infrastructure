{
  nix = {
    whitelist = [
      "overlays/default.nix"
      "ci/fmt.nix"
      "devShells.nix"
      "shell.nix"
      "lib.nix"
      "outputs.nix"
      "tree.nix"
    ];
    whitelistDirs = [
      "modules/system"
      "systems"
    ];
    blacklistDirs = [
      "overlays"
      "ci"
    ];
  };
}
