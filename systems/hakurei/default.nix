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
      address4 = "100.71.65.59";
      address6 = "fd7a:115c:a1e0::9187:413b";
    };
  };
  access = {
    global.enable = true;
  };
  exports = {
    services = {
      tailscale.enable = true;
      samba.enable = true;
      vouch-proxy = {
        enable = true;
        id = "login.local";
      };
    };
    exports = {
      plex.enable = true;
    };
  };
}
