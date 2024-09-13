_: {
  imports = [
    ./proxmox.nix
  ];
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  network.networks = {
    tail = {
      address4 = "100.104.170.16";
      address6 = "fd7a:115c:a1e0::ee01:aa11";
    };
  };
  exports = {
    services = {
      tailscale.enable = true;
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
