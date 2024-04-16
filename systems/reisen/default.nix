_: {
  type = "Linux";
  proxmox.node = {
    enable = true;
  };
  extern.files = {
    "/etc/sysctl.d/50-net.conf" = {
      source = ./sysctl.50-net.conf;
    };
    "/etc/network/interfaces.d/50-vmbr0-ipv6.conf" = {
      source = ./net.50-vmbr0-ipv6.conf;
    };
    "/etc/udev/rules.d/90-dri.rules" = {
      source = ./udev.90-dri.rules;
    };
    "/etc/udev/rules.d/90-z2m.rules" = {
      source = ./udev.90-z2m.rules;
    };
  };
  network.networks = {
    local = {
      address4 = "10.1.1.40";
      address6 = null;
    };
    int = {
      address4 = "10.9.1.2";
      address6 = "fd0c::2";
    };
  };
  exports = {
    services = {
      sshd = {
        enable = true;
        ports.public.enable = false;
      };
      proxmox.enable = true;
    };
  };
}
