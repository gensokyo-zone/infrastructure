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
      nginx = {
        enable = true;
        ports = {
          https_global = {
            port = 443;
            protocol = "https";
            listen = "wan";
          };
          https = {
            enable = true;
            port = 444;
          };
          http.listen = "wan";
        };
      };
      sshd = {
        enable = true;
        ports.global = {
          port = 41022;
          transport = "tcp";
          listen = "wan";
        };
      };
    };
    exports = {
      plex.enable = true;
    };
  };
}
