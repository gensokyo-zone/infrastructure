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
      nginx.enable = true;
      plex.enable = true;
      invidious.enable = true;
    };
  };
}
