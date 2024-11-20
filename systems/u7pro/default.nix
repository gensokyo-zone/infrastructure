_: {
  type = "Linux";
  access = {
    hostName = "u7-pro";
    online.available = true;
  };
  network.networks = {
    local = {
      address4 = "10.1.1.3";
      address6 = null;
    };
  };
  exports = {
    status.displayName = "U7 Pro";
    services = {
      sshd = {
        enable = true;
        ports.public.enable = false;
      };
    };
  };
}
