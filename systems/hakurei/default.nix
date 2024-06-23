{lib, ...}: {
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
      syncplay.enable = true;
      vouch-proxy = {
        enable = true;
        displayName = "Vouch Proxy/local";
        id = "login.local";
      };
      nginx = let
        inherit (lib.modules) mkIf;
        preread = false;
      in {
        enable = true;
        ports = {
          https_global = mkIf preread {
            port = 443;
            protocol = "https";
            listen = "wan";
          };
          https = {
            port = mkIf preread 444;
            listen = mkIf (!preread) "wan";
          };
          http.listen = "wan";
          proxied.enable = true;
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
