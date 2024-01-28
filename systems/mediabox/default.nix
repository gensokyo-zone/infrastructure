_: {
  deploy.hostname = "mediabox.local.gensokyo.zone";
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
}
