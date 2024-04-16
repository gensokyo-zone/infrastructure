_: {
  type = "Linux";
  extern.files = {
    "/etc/dhcpcd.conf" = {
      source = ./dhcpcd.conf;
    };
    "/etc/motion/motion.conf" = {
      source = ./motion.conf;
    };
  };
  network.networks = {
    local = {
      # TODO: macAddress = ?;
      address4 = null;
      address6 = "fd0a::ba27:ebff:fea8:f4ff";
    };
  };
  exports = {
    services = {
      sshd = {
        enable = true;
        ports.public.enable = false;
      };
      motion = {
        id = "kitchen";
        enable = true;
        ports.stream.port = 41081;
      };
    };
  };
}
