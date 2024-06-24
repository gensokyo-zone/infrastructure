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
      nginx = {
        enable = true;
        ports.proxied.enable = true;
      };
      cloudflared.enable = true;
      plex.enable = true;
      invidious.enable = true;
      deluge.enable = true;
    };
  };
}
