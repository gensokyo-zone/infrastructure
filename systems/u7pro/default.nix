_: {
  type = "Linux";
  access.hostName = "u7-pro";
  network.networks = {
    local = {
      address4 = "10.1.1.3";
      address6 = null;
    };
  };
  exports = {
    services = {
      sshd = {
        enable = true;
        ports.public.enable = false;
      };
    };
  };
}
