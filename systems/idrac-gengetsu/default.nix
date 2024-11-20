_: {
  type = "Linux";
  access = {
    online.available = true;
  };
  network.networks = {
    local = {
      slaac.enable = false;
      address4 = "10.1.1.12";
      address6 = null;
    };
  };
  exports = {
    status.displayName = "gengetsu/IDRAC";
    services = {
      sshd = {
        enable = true;
        ports.public.enable = false;
      };
    };
  };
}
