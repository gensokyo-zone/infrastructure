{
  nix = {
    whitelist = [
      "overlays/default.nix"
      "ci/fmt.nix"
      "docs/derivation.nix"
      "devShells.nix"
      "shell.nix"
      "generate.nix"
      "lib.nix"
      "outputs.nix"
      "tree.nix"
    ];
    whitelistDirs = [
      "modules/extern"
      "modules/nixos"
      "modules/system"
      "nixos"
      "overlays"
      "packages"
      "systems"
    ];
    blacklistDirs = [
      "modules/nixos/ldap"
      "ci"
    ];
  };
}
