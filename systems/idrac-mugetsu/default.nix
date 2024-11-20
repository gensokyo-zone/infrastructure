_: {
  type = "Linux";
  access = {
    online.available = true;
  };
  network.networks = {
    local = {
      slaac.enable = false;
      address4 = "10.1.1.13";
      address6 = null;
    };
  };
  exports = {
    status.displayName = "mugetsu/IDRAC";
    services = {
      sshd = {
        enable = true;
        ports.public.enable = false;
      };
    };
  };
}
