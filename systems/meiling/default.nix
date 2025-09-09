{lib, config, ...}: {
  type = "Linux";
  proxmox.node = {
    enable = true;
  };
  access = {
    online.available = true;
    global.enable = true;
  };
  extern.files = {
    "/etc/sysctl.d/50-net.conf" = {
      source = ./sysctl.50-net.conf;
    };
  };
  network.networks = {
    global = {
      address4 = "49.12.128.117";
      address6 = "2a01:4f8:242:598d::4";
    };
    local = {
      inherit (config.network.networks.global) address4;
      address6 = null;
    };
    int = {
      address4 = "10.9.2.4";
      address6 = "fd0c:0:0:2::4";
    };
    tail = {
      address4 = "100.67.99.30";
      address6 = "fd7a:115c:a1e0::dc34:631e";
    };
  };
  exports = {
    services = {
      tailscale.enable = true;
      sshd = {
        enable = true;
        ports = {
          public.enable = false;
          standard.listen = "wan";
        };
      };
      proxmox = {
        enable = true;
        id = "proxmox-meiling";
      };
    };
  };
}
