_: {
  type = "Linux";
  access = {
    online.available = true;
  };
  network.networks = {
    local = {
      address4 = "10.1.1.12";
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
