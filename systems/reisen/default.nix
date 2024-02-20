_: {
  type = "Linux";
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
      proxmox.enable = true;
    };
  };
}
