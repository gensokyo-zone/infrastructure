{...}: {
  type = "Linux";
  network.networks = {
    local = {
      slaac.enable = false;
      address4 = "10.1.1.9";
      address6 = null;
    };
    tail = {
      address4 = "100.127.157.98";
      address6 = "fd7a:115c:a1e0::1901:9d62";
    };
  };
  exports.services = {
    tailscale.enable = true;
    sshd.enable = true;
    #nkvm.enable = true;
  };
}
