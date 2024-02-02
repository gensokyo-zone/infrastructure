{
  nix = {
    whitelist = [
      "systems/default.nix"
      "systems/ct/default.nix"
      "systems/ct/nixos.nix"
      "systems/hakurei/default.nix"
      "systems/kuwubernetes/default.nix"
      "systems/kuwubernetes/nixos.nix"
      "systems/mediabox/default.nix"
      "systems/mediabox/nixos.nix"
      "systems/reimu/default.nix"
      "systems/tei/default.nix"
      "systems/tei/nixos.nix"
      "systems/tei/cloudflared.nix"
      "systems/tewi/default.nix"
      "systems/tewi/nixos.nix"
      "overlays/default.nix"
      "devShells.nix"
      "shell.nix"
      "outputs.nix"
      "tree.nix"
    ];
    blacklistDirs = [
      "overlays"
      "ci"
    ];
  };
}
