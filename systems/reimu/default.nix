_: {
  imports = [
    ./proxmox.nix
  ];
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  exports = {
    services = {
      sshd.enable = true;
      tailscale.enable = true;
      nfs.enable = true;
    };
  };
}
