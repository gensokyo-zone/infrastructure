_: {
  imports = [
    ./proxmox.nix
  ];
  arch = "x86_64";
  type = "NixOS";
  ci.allowFailure = true;
  modules = [
    ./nixos.nix
  ];
  exports = {
    services = {
      tailscale.enable = true;
    };
  };
}
