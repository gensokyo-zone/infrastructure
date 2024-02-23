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
      "systems"
    ];
    blacklistDirs = [
      "overlays"
      "ci"
    ];
  };
}
