_: {
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  access = {
    tailscale.enable = true;
    global.enable = true;
  };
}
