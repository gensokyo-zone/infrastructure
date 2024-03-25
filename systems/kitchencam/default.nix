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
}
